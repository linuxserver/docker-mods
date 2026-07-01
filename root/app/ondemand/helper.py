import docker
import requests
from typing import Optional


def get_docker_client(docker_host_url: str, from_env: bool = False) -> tuple[Optional[docker.DockerClient], str]:
    try:
        if docker_host_url:
            if not docker_host_url.startswith("tcp://"):
                docker_host_url = f"tcp://{docker_host_url}:2375"
            return docker.DockerClient(base_url=docker_host_url), docker_host_url
        elif from_env:
            return docker.from_env(), "unix://var/run/docker.sock"
        else:
            return None, ""
    except (docker.errors.DockerException, requests.exceptions.ConnectionError):
        return None, ""
    
def is_docker_connected(client: docker.DockerClient) -> bool:
    try:
        return client.ping()
    except (docker.errors.DockerException, requests.exceptions.ConnectionError):
        return False
    