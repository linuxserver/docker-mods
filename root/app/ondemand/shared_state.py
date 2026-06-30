import threading

last_accessed_urls = set()
last_accessed_urls_lock = threading.Lock()
