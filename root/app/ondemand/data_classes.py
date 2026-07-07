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
    client: docker.DockerClient
    url: str
    is_connected: bool = False
    ondemand_containers: dict[str, OnDemandContainer] = field(default_factory=dict)
