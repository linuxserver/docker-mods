from datetime import datetime
import docker
import logging
import os
import threading
import time

ACCESS_LOG_FILE = "/config/log/nginx/access.log"
LOG_FILE = "/config/log/ondemand/ondemand.log"
CONTAINER_QUERY_SLEEP = float(os.environ.get("SWAG_ONDEMAND_CONTAINER_QUERY_SLEEP", "5.0"))
LOG_READER_SLEEP = float(os.environ.get("SWAG_ONDEMAND_LOG_READER_SLEEP", "1.0"))
STOP_THRESHOLD = int(os.environ.get("SWAG_ONDEMAND_STOP_THRESHOLD", "600"))
REMOTE_HOSTS_PREFIX = "SWAG_ONDEMAND_REMOTE"

last_accessed_urls = set()
last_accessed_urls_lock = threading.Lock()

class ContainerThread(threading.Thread):
    def __init__(self):
        super().__init__()
        self.daemon = True
        self.ondemand_containers = {}
        self.init_docker_hosts()
        self.docker_hosts = []

    def init_docker_hosts(self):
        try:
            docker_host = {}
            docker_host_url = os.environ.get("DOCKER_HOST", None)
            if docker_host_url:
                if not docker_host_url.startswith("tcp://"):
                    docker_host_url = f"tcp://{docker_host_url}:2375"
                docker_host["docker_client"] = docker.DockerClient(base_url=docker_host_url)
            else:
                docker_host["docker_client"] = docker.from_env()
            self.docker_hosts.append(docker_host)
        except Exception:
            pass
    
        try:
            remote_hosts_env_vars = { key: value for key, value in os.environ.items() if key.startswith(REMOTE_HOSTS_PREFIX) }
            for i in range(1, 20):
                remote_host = {}
                if f"{REMOTE_HOSTS_PREFIX}{i}" not in remote_hosts_env_vars:
                    break
                docker_host_url = remote_hosts_env_vars[f"{REMOTE_HOSTS_PREFIX}{i}"]
                if not docker_host_url.startswith("tcp://"):
                    docker_host_url = f"tcp://{docker_host_url}:2375"
                remote_host["docker_host"] = docker_host_url
                remote_host["docker_client"] = docker.DockerClient(base_url=docker_host_url)
                if f"{REMOTE_HOSTS_PREFIX}{i}_MAC" in remote_hosts_env_vars:
                    remote_host["mac"] = remote_hosts_env_vars[f"{REMOTE_HOSTS_PREFIX}{i}_MAC"]
                if f"{REMOTE_HOSTS_PREFIX}{i}_IP" in remote_hosts_env_vars:
                    remote_host["ip"] = remote_hosts_env_vars[f"{REMOTE_HOSTS_PREFIX}{i}_IP"]
                if f"{REMOTE_HOSTS_PREFIX}{i}_URLS" in remote_hosts_env_vars:
                    remote_host["urls"] = remote_hosts_env_vars[f"{REMOTE_HOSTS_PREFIX}{i}_URLS"]
                self.docker_hosts.append(remote_host)
        except Exception:
            pass

        if not self.docker_hosts:
            logging.error("Failed to connect to any docker host")

    def process_containers(self):
        for docker_host in self.docker_hosts:
            docker_client = docker_host["docker_client"]
            containers = docker_client.containers.list(all=True, filters={ "label": ["swag_ondemand=enable"] })
            container_names = {container.name for container in containers}

            for container_name in list(self.ondemand_containers.keys()):
                if container_name in container_names:
                    continue
                self.ondemand_containers.pop(container_name)
                logging.info(f"Stopped monitoring {container_name}")

            for container in containers:
                default_url = container.labels.get("swag_url", f"{container.name}.").rstrip("*")
                container_urls = container.labels.get("swag_ondemand_urls", f"https://{default_url},http://{default_url}")
                if container.name not in self.ondemand_containers.keys():
                    last_accessed = datetime.now()
                    logging.info(f"Started monitoring {container.name} for urls: {container_urls}")
                else:
                    last_accessed = self.ondemand_containers[container.name]["last_accessed"]
                    if container_urls != self.ondemand_containers[container.name]["urls"]:
                        logging.info(f"Updated urls for {container.name} to: {container_urls}")
                self.ondemand_containers[container.name] = { "docker_client": docker_client, "status": container.status, "urls": container_urls, "last_accessed": last_accessed }

    def stop_containers(self):
        for container_name in self.ondemand_containers.keys():
            if self.ondemand_containers[container_name]["status"] != "running":
                continue
            inactive_seconds = (datetime.now() - self.ondemand_containers[container_name]["last_accessed"]).total_seconds()
            if inactive_seconds < STOP_THRESHOLD:
                continue
            docker_client = self.ondemand_containers[container_name]["docker_client"]
            docker_client.containers.get(container_name).stop()
            logging.info(f"Stopped {container_name} after {STOP_THRESHOLD}s of inactivity")

    def start_containers(self):
        with last_accessed_urls_lock:
            last_accessed_urls_combined = ",".join(last_accessed_urls)
            last_accessed_urls.clear()

        for container_name in self.ondemand_containers.keys():
            accessed = False
            for ondemand_url in self.ondemand_containers[container_name]["urls"].split(","):
                if ondemand_url not in last_accessed_urls_combined:
                    continue
                self.ondemand_containers[container_name]["last_accessed"] = datetime.now()
                accessed = True
            if not accessed or self.ondemand_containers[container_name]["status"] == "running":
                continue
            docker_client = self.ondemand_containers[container_name]["docker_client"]
            docker_client.containers.get(container_name).start()
            logging.info(f"Started {container_name}")
            self.ondemand_containers[container_name]["status"] = "running"

    def run(self):
        while True:
            try:
                self.process_containers()
                self.start_containers()
                self.stop_containers()
                time.sleep(CONTAINER_QUERY_SLEEP)
            except Exception as e:
                logging.exception(e)

class LogReaderThread(threading.Thread):
    def __init__(self):
        super().__init__()
        self.daemon = True

    def tail(self, f):
        f.seek(0,2)
        inode = os.fstat(f.fileno()).st_ino

        while True:
            line = f.readline()
            if not line:
                time.sleep(LOG_READER_SLEEP)
                if os.stat(ACCESS_LOG_FILE).st_ino != inode:
                    f.close()
                    f = open(ACCESS_LOG_FILE, 'r')
                    inode = os.fstat(f.fileno()).st_ino
                continue
            yield line

    def run(self):
        while True:
            try:
                if not os.path.exists(ACCESS_LOG_FILE):
                    time.sleep(1)
                    continue

                logfile = open(ACCESS_LOG_FILE, "r")
                for line in self.tail(logfile):
                    if '" 302 ' in line:
                        continue
                    for part in line.split():
                        if not part.startswith("http"):
                            continue
                        with last_accessed_urls_lock:
                            last_accessed_urls.add(part)
                        break
            except Exception as e:
                logging.exception(e)
                time.sleep(1)

if __name__ == "__main__":
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    logging.basicConfig(filename=LOG_FILE,
                    filemode='a',
                    format='%(asctime)s - %(threadName)s - %(levelname)s - %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S',
                    level=logging.INFO)
    logging.info("Starting swag-ondemand...")

    ContainerThread().start()
    LogReaderThread().start()

    while True:
        time.sleep(1)
