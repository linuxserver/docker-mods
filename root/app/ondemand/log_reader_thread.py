from shared_state import last_accessed_urls, last_accessed_urls_lock

import logging
import os
import threading
import time

ACCESS_LOG_FILE = "/config/log/nginx/access.log"
LOG_READER_SLEEP = float(os.environ.get("SWAG_ONDEMAND_LOG_READER_SLEEP", "1.0"))


class LogReaderThread(threading.Thread):
    def __init__(self):
        super().__init__(name="LogReaderThread")
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
