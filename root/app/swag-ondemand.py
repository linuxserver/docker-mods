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

last_accessed_urls = set()
last_accessed_urls_lock = threading.Lock()

class ContainerThread(threading.Thread):
    def __init__(self):
        super().__init__()
        self.daemon = True
        self.ondemand_containers = {}
        self.init_docker()
            
    def init_docker(self):
        try:
            docker_host = os.environ.get("DOCKER_HOST", None)
            if docker_host:
                if not docker_host.startswith("tcp://"):
                    docker_host = f"tcp://{docker_host}:2375"
                self.docker_client = docker.DockerClient(base_url=docker_host)
            else:
                self.docker_client = docker.from_env()
        except Exception as e:
            logging.exception(e)
            os._exit(1)

    def process_containers(self):
        containers = self.docker_client.containers.list(all=True, filters={ "label": ["swag_ondemand=enable"] })
        container_names = {container.name for container in containers}
        
        for container_name in list(self.ondemand_containers.keys()):
            if container_name in container_names:
                continue
            self.ondemand_containers.pop(container_name)
            logging.info(f"Stopped monitoring {container_name}")
        
        for container in containers:
            container_urls = container.labels.get("swag_ondemand_urls", f"https://{container.name}.,http://{container.name}.")
            if container.name not in self.ondemand_containers.keys():
                last_accessed = datetime.now()
                logging.info(f"Started monitoring {container.name}")
            else:
                last_accessed = self.ondemand_containers[container.name]["last_accessed"]
            self.ondemand_containers[container.name] = { "status": container.status, "urls": container_urls, "last_accessed": last_accessed }

    def stop_containers(self):
        for container_name in self.ondemand_containers.keys():
            if self.ondemand_containers[container_name]["status"] != "running":
                continue
            inactive_seconds = (datetime.now() - self.ondemand_containers[container_name]["last_accessed"]).total_seconds()
            if inactive_seconds < STOP_THRESHOLD:
                continue
            self.docker_client.containers.get(container_name).stop()
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
            self.docker_client.containers.get(container_name).start()
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
