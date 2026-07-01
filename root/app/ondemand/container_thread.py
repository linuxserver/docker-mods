from data_classes import DockerHost, OnDemandContainer
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
        self.docker_hosts: list[DockerHost] = []
        self.init_docker_hosts()

    def init_docker_hosts(self):
        docker_host_url = os.environ.get("DOCKER_HOST", None)
        client, url = helper.get_docker_client(docker_host_url, True)
        if client:
            self.docker_hosts.append(DockerHost(client=client, url=url))
    
        remote_hosts_env_vars = { key: value for key, value in os.environ.items() if key.startswith(REMOTE_HOSTS_PREFIX) }
        for i in range(1, 20):
            if f"{REMOTE_HOSTS_PREFIX}{i}" not in remote_hosts_env_vars:
                break
            
            docker_host_url = remote_hosts_env_vars[f"{REMOTE_HOSTS_PREFIX}{i}"]
            client, url = helper.get_docker_client(docker_host_url)
            
            if client:
                self.docker_hosts.append(DockerHost(client=client, url=url))

        if not self.docker_hosts:
            logging.error("Failed to connect to any docker host")
    
    def process_containers(self):
        for docker_host in self.docker_hosts:
            if not helper.is_docker_connected(docker_host.client):
                if docker_host.is_connected:
                    logging.warning(f"Lost connection to {docker_host.url}")
                docker_host.is_connected = False
                continue

            if not docker_host.is_connected:
                logging.info(f"Connection to {docker_host.url} has been restored")
                docker_host.is_connected = True

            containers = docker_host.client.containers.list(all=True, filters={ "label": ["swag_ondemand=enable"] })
            container_names = {container.name for container in containers}

            for container_name in list(docker_host.ondemand_containers.keys()):
                if container_name not in container_names:
                    docker_host.ondemand_containers.pop(container_name)
                    logging.info(f"Stopped monitoring {container_name}")

            for container in containers:
                default_url = container.labels.get("swag_url", f"{container.name}.").rstrip("*")
                container_urls = container.labels.get("swag_ondemand_urls", f"https://{default_url},http://{default_url}")
                
                if container.name not in docker_host.ondemand_containers:
                    last_accessed = datetime.now()
                    logging.info(f"Started monitoring {container.name} for urls: {container_urls}")
                else:
                    existing_container = docker_host.ondemand_containers[container.name]
                    last_accessed = existing_container.last_accessed
                    if container_urls != existing_container.urls:
                        logging.info(f"Updated urls for {container.name} to: {container_urls}")
                
                docker_host.ondemand_containers[container.name] = OnDemandContainer(
                    status=container.status,
                    urls=container_urls,
                    last_accessed=last_accessed
                )

    def stop_containers(self):
        for docker_host in self.docker_hosts:
            for container_name, container in docker_host.ondemand_containers.items():
                if container.status != "running":
                    continue
                
                inactive_seconds = (datetime.now() - container.last_accessed).total_seconds()
                if inactive_seconds < STOP_THRESHOLD:
                    continue
                
                if not helper.is_docker_connected(docker_host.client):
                    logging.warning(f"Failed to stop {container_name}, docker host {docker_host.url} is unavailable")
                    continue
                
                docker_host.client.containers.get(container_name).stop()
                logging.info(f"Stopped {container_name} after {STOP_THRESHOLD}s of inactivity")

    def start_containers(self):
        with last_accessed_urls_lock:
            last_accessed_urls_combined = ",".join(last_accessed_urls)
            last_accessed_urls.clear()

        for docker_host in self.docker_hosts:
            for container_name, container in docker_host.ondemand_containers.items():
                accessed = False
                for ondemand_url in container.urls.split(","):
                    if ondemand_url in last_accessed_urls_combined:
                        container.last_accessed = datetime.now()
                        accessed = True
                        break
                
                if not accessed or container.status == "running":
                    continue
                
                if not helper.is_docker_connected(docker_host.client):
                    logging.warning(f"Failed to start {container_name}, docker host {docker_host.url} is unavailable")
                    continue
                
                docker_host.client.containers.get(container_name).start()
                logging.info(f"Started {container_name}")
                container.status = "running"

    def run(self):
        while True:
            try:
                self.process_containers()
                self.start_containers()
                self.stop_containers()
                time.sleep(CONTAINER_QUERY_SLEEP)
            except Exception as e:
                logging.exception(e)
