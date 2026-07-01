from dataclasses import dataclass, field
from datetime import datetime
import docker

@dataclass
class OnDemandContainer:
    status: str
    urls: str
    last_accessed: datetime

@dataclass
class DockerHost:
    docker_client: docker.DockerClient
    docker_host_url: str
    is_connected: bool = False
    ondemand_containers: dict = field(default_factory=dict)
