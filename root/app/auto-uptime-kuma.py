from auto_uptime_kuma.config_service import ConfigService
from auto_uptime_kuma.uptime_kuma_service import UptimeKumaService
from auto_uptime_kuma.docker_service import DockerService
from auto_uptime_kuma.log import Log
import sys, os


def add_or_update_monitors(
    docker_service: DockerService,
    config_service: ConfigService,
    uptime_kuma_service: UptimeKumaService,
):
    for container in docker_service.get_swag_containers():
        container_config = docker_service.parse_container_labels(
            container.labels, ".monitor."
        )
        container_name = container.name
        monitor_data = uptime_kuma_service.build_monitor_data(
            container_name, container_config
        )

        if not uptime_kuma_service.monitor_exists(container_name):
            uptime_kuma_service.create_monitor(container_name, container_config)
        else:
            if not config_service.config_exists(container_name):
                Log.info(
                    f"Monitor '{monitor_data['name']}' for container '{container_name}'"
                    " exists but no preset config found, generating from scratch"
                )
                config_service.create_config(container_name, monitor_data)
            uptime_kuma_service.edit_monitor(container_name, monitor_data)


def delete_removed_monitors(
    docker_service: DockerService, uptime_kuma_service: UptimeKumaService
):
    Log.info("Searching for Monitors that should be deleted")
    # Monitors to be deleted are those that no longer have an existing container
    # Monitor <-> Container link is done by comparing the container name
    # with the monitor swag tag value
    existing_monitor_names = [
        uptime_kuma_service.get_monitor_swag_tag_value(monitor)
        for monitor in uptime_kuma_service.monitors
    ]
    existing_container_names = [
        container.name for container in docker_service.get_swag_containers()
    ]

    monitors_to_be_deleted = [
        containerName
        for containerName in existing_monitor_names
        if containerName not in existing_container_names
    ]

    monitors_to_be_deleted = list(filter(None, monitors_to_be_deleted))

    uptime_kuma_service.delete_monitors(monitors_to_be_deleted)


def delete_removed_groups(uptime_kuma_service: UptimeKumaService):
    Log.info("Searching for Groups that should be deleted")
    # Groups to be deleted are those that no longer have any child Monitors
    existing_monitor_group_ids = [
        monitor["parent"] for monitor in uptime_kuma_service.monitors
    ]

    # remove empty values
    existing_monitor_group_ids = list(filter(None, existing_monitor_group_ids))
    # get unique values
    existing_monitor_group_ids = list(set(existing_monitor_group_ids))

    groups_to_be_deleted = []

    for group in uptime_kuma_service.groups:
        if group["id"] not in existing_monitor_group_ids:
            groups_to_be_deleted.append(group["name"])

    uptime_kuma_service.delete_groups(groups_to_be_deleted)


def execute_cli_mode(
    config_service: ConfigService, uptime_kuma_service: UptimeKumaService
):
    Log.info("Mod was executed from CLI. Running manual tasks.")
    args = config_service.get_cli_args()
    if args.purge:
        uptime_kuma_service.purge_data()

        config_service.purge_data()
    if args.monitor:
        Log.info(f"Requesting data for Monitor '{args.monitor}'")
        print(uptime_kuma_service.get_monitor(args.monitor))

    uptime_kuma_service.disconnect()


if __name__ == "__main__":
    Log.init("mod-auto-uptime-kuma")

    url = os.environ["UPTIME_KUMA_URL"]
    username = os.environ["UPTIME_KUMA_USERNAME"]
    password = os.environ["UPTIME_KUMA_PASSWORD"]
    domainName = os.environ["URL"]

    configService = ConfigService(domainName)
    uptimeKumaService = UptimeKumaService(configService)
    dockerService = DockerService("swag.uptime-kuma")
    is_connected = uptimeKumaService.connect(url, username, password)

    if not is_connected:
        sys.exit()

    uptimeKumaService.load_data()
    if uptimeKumaService.default_notifications:
        notification_names = [
            f"{notification['id']}:{notification['name']}"
            for notification in uptimeKumaService.default_notifications
        ]
        Log.info(
            f"The following notifications are enabled by default: {notification_names}"
        )

    if configService.is_cli_mode():
        execute_cli_mode(configService, uptimeKumaService)
        sys.exit()

    add_or_update_monitors(dockerService, configService, uptimeKumaService)

    # reload data after the sync above
    uptimeKumaService.load_data()
    # cleanup
    delete_removed_monitors(dockerService, uptimeKumaService)
    delete_removed_groups(uptimeKumaService)

    uptimeKumaService.disconnect()
