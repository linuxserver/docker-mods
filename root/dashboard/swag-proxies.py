import collections
import concurrent.futures
import glob
import json
import os
import re
import requests
import urllib3


def find_apps():
    apps = {}
    file_paths = glob.glob("/config/nginx/**/*", recursive=True)
    auto_confs = glob.glob("/etc/nginx/http.d/*", recursive=True)
    file_paths.extend(auto_confs)
    for file_path in file_paths:
        if not os.path.isfile(file_path):
            continue
        file = open(file_path, "r")
        content = file.read()
        results = re.finditer(r"(\s+)set \$upstream_app (?P<name>\S+?);.*\n(\s+)set \$upstream_port (?P<port>\d+);.*\n(\s+)set \$upstream_proto (?P<proto>\w+);.*", content)
        for result in results:
            params = result.groupdict()
            app = f"{params['proto']}://{params['name']}:{params['port']}/"
            if app not in apps:
                apps[app] = set()
            if file_path.startswith("/config/nginx/site-confs/") or file_path.endswith(".conf"):
                file_path = "auto-proxy" if file_path.startswith("/etc/nginx/http.d/") else file_path
                apps[app].add(file_path)
    return apps


def is_available(url):
    try:
        requests.head(url, timeout=5, verify=False)
        return True
    except:
        return False

urllib3.disable_warnings()
apps = find_apps()
discovered_apps = collections.defaultdict(dict)
with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
    futures = {executor.submit(is_available, app): app for app in apps.keys()}
    for future in concurrent.futures.as_completed(futures):
        app = futures[future]
        if not future.result() and not apps[app]:
            continue
        discovered_apps[app]["status"] = future.result()
        discovered_apps[app]["locations"] = list(apps[app])

print(json.dumps(discovered_apps, sort_keys=True))
