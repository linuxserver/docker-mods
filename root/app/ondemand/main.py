from container_thread import ContainerThread
from log_reader_thread import LogReaderThread

import logging
import os
import time

LOG_FILE = "/config/log/ondemand/ondemand.log"


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
