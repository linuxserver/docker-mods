import logging
import os
import time

from container_thread import ContainerThread
from healthcheck_thread import HealthcheckThread
from log_reader_thread import LogReaderThread

LOG_FILE = "/config/log/ondemand/ondemand.log"


if __name__ == "__main__":
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    logging.basicConfig(
        filename=LOG_FILE,
        filemode="a",
        format="%(asctime)s - %(threadName)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        level=logging.INFO,
    )
    logging.info("Starting swag-ondemand...")

    container_thread = ContainerThread()
    healthcheck_thread = HealthcheckThread(container_thread.docker_hosts)
    log_reader_thread = LogReaderThread()

    healthcheck_thread.start()
    container_thread.start()
    log_reader_thread.start()

    while True:
        time.sleep(1)
