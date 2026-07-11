import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

import docker
import requests


@dataclass
class OnDemandContainer:
    status: str
    urls: str
    last_accessed: datetime
    websocket: bool
    terminated: bool = False


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

    def check_connection(self, timeout: int):
        try:
            self.was_connected = self.is_connected
            if self.client and self.client.ping():
                self.is_connected = True
                return

            if self.url:
                self.client = docker.DockerClient(base_url=self.url, timeout=timeout)
            else:
                self.client = docker.from_env(timeout=timeout)
                self.url = "unix:///var/run/docker.sock"

            self.is_connected = True
            if not self.was_connected:
                logging.info(f"Connection to {self.url} has been restored")
        except docker.errors.DockerException, requests.exceptions.ConnectionError, requests.exceptions.ReadTimeout:
            self.client = None
            self.is_connected = False
            if self.was_connected:
                logging.warning(f"Lost connection to {self.url} during health check")

    def handle_disconnect(self):
        self.client = None
        self.is_connected = False
        logging.warning(f"Lost connection to {self.url} during runtime operation")

    def get_container(self, container_name: str):
        try:
            client = self.client
            if not client or not self.is_connected:
                return None
            return client.containers.get(container_name)
        except docker.errors.DockerException, requests.exceptions.ConnectionError, requests.exceptions.ReadTimeout:
            self.handle_disconnect()
            return None

    def get_containers(self):
        try:
            client = self.client
            if not client or not self.is_connected:
                return None
            return client.containers.list(all=True, filters={"label": ["swag_ondemand=enable"]})
        except docker.errors.DockerException, requests.exceptions.ConnectionError, requests.exceptions.ReadTimeout:
            self.handle_disconnect()
            return None
