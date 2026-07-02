from data_classes import DockerHost, OnDemandContainer
from shared_state import last_accessed_urls, last_accessed_urls_lock

from datetime import datetime
import logging
import os
import threading
import time
import wakeonlan

CONTAINER_QUERY_SLEEP = float(os.environ.get("SWAG_ONDEMAND_CONTAINER_QUERY_SLEEP", "5.0"))
DOCKER_API_TIMEOUT = int(os.environ.get("SWAG_ONDEMAND_DOCKER_API_TIMEOUT", "5"))
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
        if docker_host_url and not docker_host_url.startswith("tcp://"):
            docker_host_url = f"tcp://{docker_host_url}:2375"
        self.docker_hosts.append(DockerHost(url=docker_host_url))
    
        remote_hosts_env_vars = { key: value for key, value in os.environ.items() if key.startswith(REMOTE_HOSTS_PREFIX) }
        for i in range(1, 21):
            if f"{REMOTE_HOSTS_PREFIX}{i}" not in remote_hosts_env_vars:
                break
            
            docker_host_url = remote_hosts_env_vars[f"{REMOTE_HOSTS_PREFIX}{i}"]
            if docker_host_url and not docker_host_url.startswith("tcp://"):
                docker_host_url = f"tcp://{docker_host_url}:2375"
            remote_host = DockerHost(url=docker_host_url)
            remote_host.wol_mac = remote_hosts_env_vars.get(f"{REMOTE_HOSTS_PREFIX}{i}_WOL_MAC", None)
            remote_host.wol_broadcast = remote_hosts_env_vars.get(f"{REMOTE_HOSTS_PREFIX}{i}_WOL_BROADCAST", "255.255.255.255")
            remote_host.wol_urls = remote_hosts_env_vars.get(f"{REMOTE_HOSTS_PREFIX}{i}_WOL_URLS", None)
            remote_host.wol_port = int(remote_hosts_env_vars.get(f"{REMOTE_HOSTS_PREFIX}{i}_WOL_PORT", "9"))
            remote_host.wol_interface = remote_hosts_env_vars.get(f"{REMOTE_HOSTS_PREFIX}{i}_WOL_INTERFACE", None)
            self.docker_hosts.append(remote_host)
    
    def process_containers(self):
        for docker_host in self.docker_hosts:
            docker_host.init_client(DOCKER_API_TIMEOUT)

            if not docker_host.is_connected:
                continue

            containers = docker_host.get_containers()
            if not containers:
                continue

            container_names = {container.name for container in containers}

            for container_name in list(docker_host.ondemand_containers.keys()):
                if container_name not in container_names:
                    docker_host.ondemand_containers.pop(container_name)
                    logging.info(f"Stopped monitoring {container_name} on {docker_host.url}")

            for container in containers:
                default_url = container.labels.get("swag_url", f"{container.name}.").rstrip("*")
                container_urls = container.labels.get("swag_ondemand_urls", f"https://{default_url},http://{default_url}")
                
                if container.name not in docker_host.ondemand_containers:
                    last_accessed = datetime.now()
                    logging.info(f"Started monitoring {container.name} on {docker_host.url} for urls: {container_urls}")
                else:
                    existing_container = docker_host.ondemand_containers[container.name]
                    last_accessed = existing_container.last_accessed
                    if container_urls != existing_container.urls:
                        logging.info(f"Updated urls for {container.name} on {docker_host.url} to: {container_urls}")
                
                docker_host.ondemand_containers[container.name] = OnDemandContainer(
                    status=container.status,
                    urls=container_urls,
                    last_accessed=last_accessed
                )

    def stop_containers(self):
        for docker_host in self.docker_hosts:
            for container_name, ondemand_container in docker_host.ondemand_containers.items():
                if ondemand_container.status != "running":
                    continue
                
                inactive_seconds = (datetime.now() - ondemand_container.last_accessed).total_seconds()
                if inactive_seconds < STOP_THRESHOLD:
                    continue
                
                container = docker_host.get_container(container_name)
                if not container:
                    continue
                
                container.stop()
                ondemand_container.status = "exited"
                logging.info(f"Stopped {container_name} on {docker_host.url} after {STOP_THRESHOLD}s of inactivity")

    def start_containers(self, last_accessed_urls_combined: str):
        for docker_host in self.docker_hosts:
            for container_name, ondemand_container in docker_host.ondemand_containers.items():
                accessed = False
                for ondemand_url in ondemand_container.urls.split(","):
                    if ondemand_url in last_accessed_urls_combined:
                        ondemand_container.last_accessed = datetime.now()
                        accessed = True
                        break
                
                if not accessed or ondemand_container.status == "running":
                    continue
                
                container = docker_host.get_container(container_name)
                if not container:
                    continue

                container.start()
                ondemand_container.status = "running"
                logging.info(f"Started {container_name} on {docker_host.url}")

    def send_wol(self, last_accessed_urls_combined: str):
        for docker_host in self.docker_hosts:
            if not docker_host.wol_mac or not docker_host.wol_urls or docker_host.is_connected:
                continue
            for wol_url in docker_host.wol_urls.split(","):
                if wol_url in last_accessed_urls_combined:
                    wakeonlan.send_magic_packet(docker_host.wol_mac, ip_address=docker_host.wol_broadcast, port=docker_host.wol_port, interface=docker_host.wol_interface)
                    logging.info(f"Sent a WoL packet to mac {docker_host.wol_mac} via broadcast {docker_host.wol_broadcast} on port {docker_host.wol_port} on interface {docker_host.wol_interface or 'default'} activated by {wol_url}")
                    break

    def run(self):
        while True:
            try:
                self.process_containers()
                with last_accessed_urls_lock:
                    last_accessed_urls_combined = ",".join(last_accessed_urls)
                    last_accessed_urls.clear()
                self.send_wol(last_accessed_urls_combined)
                self.start_containers(last_accessed_urls_combined)
                self.stop_containers()
                time.sleep(CONTAINER_QUERY_SLEEP)
            except Exception as e:
                logging.exception(e)
