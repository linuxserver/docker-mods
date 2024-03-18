import docker


class DockerService:
    """
    A service class for interacting with Docker containers that are used by SWAG mods.
    """

    client = None
    _containers = None
    label_prefix = None

    def __init__(self, label_prefix: str):
        self.label_prefix = label_prefix
        self.client = docker.from_env()

    def get_swag_containers(self):
        """
        Retrieve Docker containers filtered by "swag.my_mod.enabled=true":
        >>> swag = SwagDocker("swag.my_mod")
        >>> containers = swag.getSwagContainers()
        """
        if self._containers is None:
            self._containers = self.client.containers.list(
                filters={"label": [f"{self.label_prefix}.enabled=true"]}
            )
        return self._containers

    def parse_container_labels(self, container_labels, extra_prefix=""):
        """
        Having following example container labels:
        swag.my_mod.enabled: true
        swag.my_mod.config.apple: "123"
        swag.my_mod.config.orange: "456"

        >>> for container in containers:
        >>>    containerConfigA = swagDocker.parseContainerLabels(container.labels)
               # Above will return {"enabled": true, "config.apple": "123", "config.orange": "456"}
        >>>    containerConfigB = swagDocker.parseContainerLabels(container.labels, ".config.")
               # Above will return {"apple": "123", "orange": "456"}
        """
        filtered_container_labels = {}
        full_prefix = f"{self.label_prefix}{extra_prefix}"
        prefix_length = len(full_prefix)

        for label, value in container_labels.items():
            if label.startswith(full_prefix):
                parsed_label = label[prefix_length:]
                filtered_container_labels[parsed_label] = value

        return filtered_container_labels
