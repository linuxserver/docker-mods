import docker


class SwagDocker:
    """
    A service class for interacting with Docker containers that are used by SWAG mods.
    """

    client = None
    _containers = None
    _labelPrefix = None

    def __init__(self, labelPrefix: str):
        self._labelPrefix = labelPrefix
        self.client = docker.from_env()

    def getSwagContainers(self):
        """
        Retrieve Docker containers filtered by "swag.my_mod.enabled=true":
        >>> swag = SwagDocker("swag.my_mod")
        >>> containers = swag.getSwagContainers()
        """
        if self._containers is None:
            self._containers = self.client.containers.list(
                filters={"label": [f"{self._labelPrefix}.enabled=true"]})
        return self._containers

    def parseContainerLabels(self, containerLabels, extraPrefix=""):
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
        filteredContainerLabels = {}
        fullPrefix = f"{self._labelPrefix}{extraPrefix}"
        prefix_length = len(fullPrefix)

        for label, value in containerLabels.items():
            if label.startswith(fullPrefix):
                parsedLabel = label[prefix_length:]
                filteredContainerLabels[parsedLabel] = value

        return filteredContainerLabels
