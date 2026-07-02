from dataclasses import dataclass, field
from datetime import datetime
import docker
import logging
import requests
from typing import Optional

@dataclass
class OnDemandContainer:
    status: str
    urls: str
    last_accessed: datetime

@dataclass
class DockerHost:
    url: str
    client: Optional[docker.DockerClient] = None
    wol_mac: Optional[str] = None
    wol_broadcast: str = "255.255.255.255"
    wol_port: int = 9
    wol_interface: Optional[str] = None
    wol_urls: Optional[str] = None
    is_connected: bool = False
    was_connected: bool = False
    ondemand_containers: dict[str, OnDemandContainer] = field(default_factory=dict)

    def init_docker_client(self):
        try:
            self.was_connected = self.is_connected
            if self.client:
                return
            if self.url:
                self.client = docker.DockerClient(base_url=self.url)
            else:
                self.client = docker.from_env()
            self.is_connected = True
            if not self.was_connected:
                logging.info(f"Connection to {self.url} has been restored")
        except (docker.errors.DockerException, requests.exceptions.ConnectionError):
            self.client = None
            self.is_connected = False
            if self.was_connected:
                logging.warning(f"Lost connection to {self.url}")

    def get_container(self, container_name: str):
        try:
            return self.docker_client.containers.get(container_name)
        except (docker.errors.DockerException, requests.exceptions.ConnectionError):
            logging.warning(f"Failed to get {container_name}, docker host {self.url} is unavailable")
            return None
