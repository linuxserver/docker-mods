import threading

websocket_terminated_urls = set()
websocket_terminated_urls_lock = threading.Lock()
last_accessed_urls = set()
last_accessed_urls_lock = threading.Lock()
