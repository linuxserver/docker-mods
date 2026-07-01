import helper
from shared_state import last_accessed_urls, last_accessed_urls_lock

from datetime import datetime
import logging
import os
import threading
import time

CONTAINER_QUERY_SLEEP = float(os.environ.get("SWAG_ONDEMAND_CONTAINER_QUERY_SLEEP", "5.0"))
STOP_THRESHOLD = int(os.environ.get("SWAG_ONDEMAND_STOP_THRESHOLD", "600"))
REMOTE_HOSTS_PREFIX = "SWAG_ONDEMAND_REMOTE"


class ContainerThread(threading.Thread):
    def __init__(self):
        super().__init__(name="ContainerThread")
        self.daemon = True
        self.docker_hosts = []
        self.init_docker_hosts()

    def init_docker_hosts(self):
        docker_host = { "is_connected": False }
        docker_host["ondemand_containers"] = {}
        docker_host_url = os.environ.get("DOCKER_HOST", None)
        docker_host["docker_client"], docker_host["docker_host_url"] = helper.get_docker_client(docker_host_url, True)
        if docker_host["docker_client"]:
            self.docker_hosts.append(docker_host)
    
        remote_hosts_env_vars = { key: value for key, value in os.environ.items() if key.startswith(REMOTE_HOSTS_PREFIX) }
        for i in range(1, 20):
            remote_host = { "is_connected": False }
            remote_host["ondemand_containers"] = {}
            if f"{REMOTE_HOSTS_PREFIX}{i}" not in remote_hosts_env_vars:
                break
            docker_host_url = remote_hosts_env_vars[f"{REMOTE_HOSTS_PREFIX}{i}"]
            remote_host["docker_client"], remote_host["docker_host_url"] = helper.get_docker_client(docker_host_url)
            if not remote_host["docker_client"]:
                continue
            self.docker_hosts.append(remote_host)

        if not self.docker_hosts:
            logging.error("Failed to connect to any docker host")
    
    def process_containers(self):
        for docker_host in self.docker_hosts:
            if not helper.is_docker_connected(docker_host["docker_client"]):
                if docker_host["is_connected"]:
                    logging.warning(f"Lost connection to {docker_host['docker_host_url']}")
                docker_host["is_connected"] = False
                continue

            if not docker_host["is_connected"]:
                logging.info(f"Connection to {docker_host['docker_host_url']} has been restored")
                docker_host["is_connected"] = True

            ondemand_containers = docker_host["ondemand_containers"]
            containers = docker_host["docker_client"].containers.list(all=True, filters={ "label": ["swag_ondemand=enable"] })
            container_names = {container.name for container in containers}

            for container_name in list(ondemand_containers.keys()):
                if container_name in container_names:
                    continue
                ondemand_containers.pop(container_name)
                logging.info(f"Stopped monitoring {container_name}")

            for container in containers:
                default_url = container.labels.get("swag_url", f"{container.name}.").rstrip("*")
                container_urls = container.labels.get("swag_ondemand_urls", f"https://{default_url},http://{default_url}")
                if container.name not in ondemand_containers.keys():
                    last_accessed = datetime.now()
                    logging.info(f"Started monitoring {container.name} for urls: {container_urls}")
                else:
                    last_accessed = ondemand_containers[container.name]["last_accessed"]
                    if container_urls != ondemand_containers[container.name]["urls"]:
                        logging.info(f"Updated urls for {container.name} to: {container_urls}")
                ondemand_containers[container.name] = { "status": container.status, "urls": container_urls, "last_accessed": last_accessed }

    def stop_containers(self):
        for docker_host in self.docker_hosts:
            ondemand_containers = docker_host["ondemand_containers"]
            for container_name in ondemand_containers.keys():
                if ondemand_containers[container_name]["status"] != "running":
                    continue
                inactive_seconds = (datetime.now() - ondemand_containers[container_name]["last_accessed"]).total_seconds()
                if inactive_seconds < STOP_THRESHOLD:
                    continue
                if not helper.is_docker_connected(docker_host["docker_client"]):
                    logging.warning(f"Failed to stop {container_name}, docker host {docker_host['docker_host_url']} is unavailable")
                    continue
                docker_host["docker_client"].containers.get(container_name).stop()
                logging.info(f"Stopped {container_name} after {STOP_THRESHOLD}s of inactivity")

    def start_containers(self):
        with last_accessed_urls_lock:
            last_accessed_urls_combined = ",".join(last_accessed_urls)
            last_accessed_urls.clear()

        for docker_host in self.docker_hosts:
            ondemand_containers = docker_host["ondemand_containers"]
            for container_name in ondemand_containers.keys():
                accessed = False
                for ondemand_url in ondemand_containers[container_name]["urls"].split(","):
                    if ondemand_url not in last_accessed_urls_combined:
                        continue
                    ondemand_containers[container_name]["last_accessed"] = datetime.now()
                    accessed = True
                if not accessed or ondemand_containers[container_name]["status"] == "running":
                    continue
                if not helper.is_docker_connected(docker_host["docker_client"]):
                    logging.warning(f"Failed to start {container_name}, docker host {docker_host['docker_host_url']} is unavailable")
                    continue
                docker_host["docker_client"].containers.get(container_name).start()
                logging.info(f"Started {container_name}")
                ondemand_containers[container_name]["status"] = "running"

    def run(self):
        while True:
            try:
                self.process_containers()
                self.start_containers()
                self.stop_containers()
                time.sleep(CONTAINER_QUERY_SLEEP)
            except Exception as e:
                logging.exception(e)
