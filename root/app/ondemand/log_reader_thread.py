import logging
import os
import re
import threading
import time
from datetime import datetime

from shared_state import (
    last_accessed_urls,
    last_accessed_urls_lock,
    websocket_terminated_urls,
    websocket_terminated_urls_lock,
)

ACCESS_LOG_FILE = "/config/log/nginx/access.log"
LOG_READER_SLEEP = float(os.environ.get("SWAG_ONDEMAND_LOG_READER_SLEEP", "1.0"))
STOP_THRESHOLD = int(os.environ.get("SWAG_ONDEMAND_STOP_THRESHOLD", "600"))
TIMESTAMP_REGEX = re.compile(r"\[(\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4})\]")


class LogReaderThread(threading.Thread):
    def __init__(self):
        super().__init__(name="LogReaderThread")
        self.daemon = True

    def run(self):
        self._process_historical_logs()

        while True:
            try:
                if not os.path.exists(ACCESS_LOG_FILE):
                    time.sleep(1)
                    continue

                logfile = open(ACCESS_LOG_FILE, "r")
                for line in self._tail(logfile):
                    self._process_line(line, startup_mode=False)
            except Exception as e:
                logging.exception(e)
                time.sleep(1)

    def _process_historical_logs(self):
        if not os.path.exists(ACCESS_LOG_FILE):
            return

        try:
            with open(ACCESS_LOG_FILE, "r") as f:
                for line in f:
                    log_time = self._parse_nginx_time(line)
                    if not log_time:
                        continue
                    seconds_delta = (datetime.now() - log_time).total_seconds()
                    if seconds_delta > STOP_THRESHOLD:
                        continue
                    self._process_line(line, startup_mode=True)
        except Exception as e:
            logging.error(f"Error processing historical logs: {e}")

    def _parse_nginx_time(self, line):
        match = TIMESTAMP_REGEX.search(line)
        if match:
            try:
                return datetime.strptime(match.group(1), "%d/%b/%Y:%H:%M:%S %z")
            except ValueError:
                return None
        return None

    def _process_line(self, line, startup_mode=False):
        if '" 302 ' in line:
            return
        for part in line.split():
            if not part.startswith("http"):
                continue

            if '" 101 ' in line:
                with websocket_terminated_urls_lock:
                    websocket_terminated_urls.add(part)
            elif not startup_mode:
                with last_accessed_urls_lock:
                    last_accessed_urls.add(part)
            break

    def _tail(self, f):
        f.seek(0, 2)
        inode = os.fstat(f.fileno()).st_ino

        while True:
            line = f.readline()
            if not line:
                time.sleep(LOG_READER_SLEEP)
                if os.stat(ACCESS_LOG_FILE).st_ino != inode:
                    f.close()
                    f = open(ACCESS_LOG_FILE, "r")
                    inode = os.fstat(f.fileno()).st_ino
                continue
            yield line
