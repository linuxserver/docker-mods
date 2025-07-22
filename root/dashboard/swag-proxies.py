import collections
import concurrent.futures
import glob
import json
import os
import re
import socket
import sys
import urllib3

PROXY_REGEX = r"\s+set \$upstream_app (?P<name>\S+?);.*\n(\s+)set \$upstream_port (?P<port>\d+);.*\n(\s+)set \$upstream_proto (?P<proto>\w+);.*"
AUTHELIA_REGEX = r"\n\s+include \/config\/nginx\/authelia-location\.conf;.*"
AUTHENTIK_REGEX = r"\n\s+include \/config\/nginx\/authentik-location\.conf;.*"
BASIC_AUTH_REGEX = r"\n\s+auth_basic.*"
LDAP_REGEX = r"\n\s+include \/config\/nginx\/ldap-location\.conf;.*"
TINYAUTH_REGEX = r"\n\s+include \/config\/nginx\/tinyauth-location\.conf;.*"


def find_apps(fast=False):
    apps = {}
    auths = collections.defaultdict(dict)
    file_paths = glob.glob("/config/nginx/**/**", recursive=True)
    auto_confs = glob.glob("/etc/nginx/http.d/*", recursive=True)
    file_paths.extend(auto_confs)
    for file_path in file_paths:
        if not os.path.isfile(file_path) or (fast and file_path.endswith(".sample")):
            continue
        file = open(file_path, "r")
        content = file.read()
        match_proxy(apps, auths, content, file_path)
    return apps, auths

def match_proxy(apps, auths, content, file_path):
    results = re.finditer(PROXY_REGEX, content)
    for result in results:
        params = result.groupdict()
        app = f"{params['proto']}://{params['name']}:{params['port']}/"
        if app not in apps:
            apps[app] = set()
        if file_path.startswith("/config/nginx/site-confs/") or file_path.endswith(".conf"):
            file_path = "auto-proxy" if file_path.startswith("/etc/nginx/http.d/") else file_path
            apps[app].add(file_path)
            match_auth(auths, app, file_path, content)

def match_auth(auths, app, file_path, content):
    if re.findall(AUTHELIA_REGEX, content):
        auths[app][file_path] = "Authelia"
    elif re.findall(AUTHENTIK_REGEX, content):
        auths[app][file_path] = "Authentik"
    elif re.findall(BASIC_AUTH_REGEX, content):
        auths[app][file_path] = "Basic Auth"
    elif re.findall(LDAP_REGEX, content):
        auths[app][file_path] = "LDAP"
    elif re.findall(TINYAUTH_REGEX, content):
        auths[app][file_path] = "Tinyauth"
    else:
        auths[app][file_path] = "No Auth"

def is_available(url):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(1)
    try:
        host, port = url.split("/")[2].split(":")
        s.connect((host, int(port)))
        s.shutdown(socket.SHUT_RDWR)
        return True
    except:
        return False
    finally:
        s.close()


urllib3.disable_warnings()
fast = (len(sys.argv) > 1)
apps, auths = find_apps(fast)
discovered_apps = collections.defaultdict(dict)
with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
    futures = {executor.submit(is_available, app): app for app in apps.keys()}
    for future in concurrent.futures.as_completed(futures):
        app = futures[future]
        if not future.result() and not apps[app]:
            continue
        discovered_apps[app]["status"] = future.result()
        discovered_apps[app]["locations"] = list(apps[app])
        discovered_apps[app]["auths"] = list(f"{path} - {auth}" for path, auth in auths[app].items())
        discovered_apps[app]["auth_status"] = all(auth != "No Auth" for auth in auths[app].values())

print(json.dumps(discovered_apps, sort_keys=True))
