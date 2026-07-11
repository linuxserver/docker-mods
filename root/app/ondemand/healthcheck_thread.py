import logging
import os
import threading
import time
from concurrent.futures import ThreadPoolExecutor

from data_classes import DockerHost

DOCKER_API_TIMEOUT = int(os.environ.get("SWAG_ONDEMAND_DOCKER_API_TIMEOUT", "5"))


class HealthcheckThread(threading.Thread):
    def __init__(self, docker_hosts: list[DockerHost]):
        super().__init__(name="HealthcheckThread")
        self.daemon = True
        self.docker_hosts = docker_hosts

    def run(self):
        max_workers = max(1, len(self.docker_hosts))
        logging.info(f"Starting HealthcheckThread with a pool of {max_workers} workers.")

        with ThreadPoolExecutor(max_workers=max_workers, thread_name_prefix="HealthcheckWorker") as executor:
            while True:
                futures = [
                    executor.submit(docker_host.check_connection, DOCKER_API_TIMEOUT)
                    for docker_host in self.docker_hosts
                ]

                for future in futures:
                    try:
                        future.result()
                    except Exception as e:
                        logging.exception(e)

                time.sleep(1)
