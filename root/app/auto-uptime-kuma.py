from swagDocker import SwagDocker
from swagUptimeKuma import SwagUptimeKuma
import sys
import argparse
import os


def parseCommandLine():
    """
    Different application behavior if executed from CLI
    """
    parser = argparse.ArgumentParser()
    parser.add_argument('-purge', action='store_true')
    args = parser.parse_args()

    if (args.purge == True):
        swagUptimeKuma.purgeData()
        swagUptimeKuma.disconnect()
        sys.exit(0)


def addOrUpdateMonitors(domainName, swagContainers):
    for swagContainer in swagContainers:
        containerConfig = swagDocker.parseContainerLabels(
            swagContainer.labels, ".monitor.")
        containerName = swagContainer.name
        monitorData = swagUptimeKuma.parseMonitorData(
            containerName, domainName, containerConfig)

        if (not swagUptimeKuma.monitorExists(containerName)):
            swagUptimeKuma.addMonitor(containerName, domainName, monitorData)
        else:
            swagUptimeKuma.updateMonitor(
                containerName, domainName, monitorData)


def getMonitorsToBeRemoved(swagContainers, apiMonitors):
    # Monitors to be removed are those that no longer have an existing container
    # Monitor <-> Container link is done by comparing the container name with the monitor swag tag value
    existingMonitorNames = [swagUptimeKuma.getMonitorSwagTagValue(
        monitor) for monitor in apiMonitors]
    existingContainerNames = [container.name for container in swagContainers]

    monitorsToBeRemoved = [
        containerName for containerName in existingMonitorNames if containerName not in existingContainerNames]
    return monitorsToBeRemoved


if __name__ == "__main__":
    url = os.environ['UPTIME_KUMA_URL']
    username = os.environ['UPTIME_KUMA_USERNAME']
    password = os.environ['UPTIME_KUMA_PASSWORD']
    domainName = os.environ['URL']

    swagDocker = SwagDocker("swag.uptime-kuma")
    swagUptimeKuma = SwagUptimeKuma(url, username, password)

    parseCommandLine()

    swagContainers = swagDocker.getSwagContainers()

    addOrUpdateMonitors(domainName, swagContainers)

    monitorsToBeRemoved = getMonitorsToBeRemoved(
        swagContainers, swagUptimeKuma.apiMonitors)
    swagUptimeKuma.deleteMonitors(monitorsToBeRemoved)

    swagUptimeKuma.disconnect()
