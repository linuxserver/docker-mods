from data_classes import DockerHost

import os
import threading
import time

DOCKER_API_TIMEOUT = int(os.environ.get("SWAG_ONDEMAND_DOCKER_API_TIMEOUT", "5"))


class HealthcheckThread(threading.Thread):
    def __init__(self, docker_hosts: list[DockerHost]):
        super().__init__(name="HealthcheckThread")
        self.daemon = True
        self.docker_hosts = docker_hosts

    def run(self):
        while True:
            for docker_host in self.docker_hosts:
                docker_host.check_connection(DOCKER_API_TIMEOUT)
            time.sleep(DOCKER_API_TIMEOUT)
