import os
import sys
import argparse
from auto_uptime_kuma.log import Log
from uptime_kuma_api.api import MonitorType


class ConfigService:
    config_dir = "/auto-uptime-kuma"
    domain_name: str

    def __init__(self, domain_name):
        self.domain_name = domain_name
        if not os.path.exists(self.config_dir):
            Log.info(f"Creating config directory '{self.config_dir}'")
            os.makedirs(self.config_dir)

    def is_cli_mode(self):
        """
        Different application behavior if executed from CLI
        """
        return len(sys.argv) > 1

    def get_cli_args(self):
        parser = argparse.ArgumentParser()
        parser.add_argument("-purge", action="store_true")
        parser.add_argument("-monitor", type=str)
        return parser.parse_args()

    def merge_dicts(self, *dict_args):
        result = {}
        for dictionary in dict_args:
            result.update(dictionary)
        return result

    def create_config(self, container_name, monitor_data):
        content = self.build_config_content(monitor_data)
        self.write_config_content(container_name, content)

    def config_exists(self, container_name):
        return os.path.exists(f"{self.config_dir}/{container_name.lower()}.conf")

    def build_config_content(self, monitor_data):
        """
        In order to compare if container labels were changed the contents
        are stored in config files for each container.
        """
        content = ""
        for key, value in monitor_data.items():
            content += f"{key}={value}\n"
        return content.strip()

    def read_config_content(self, container_name):
        if not self.config_exists(container_name):
            return ""

        file_name = f"{self.config_dir}/{container_name.lower()}.conf"
        with open(file_name, "r") as file:
            return file.read().strip()

    def write_config_content(self, container_name, content):
        with open(f"{self.config_dir}/{container_name.lower()}.conf", "w+") as file:
            file.write(content)

    def purge_data(self):
        """
        Deletes all of the files created with this script
        """
        Log.info("Purging all Docker container configuration added by this mod")

        if os.path.exists(self.config_dir):
            Log.info(f"Purging config directory '{self.config_dir}' and its content")
            file_list = os.listdir(self.config_dir)

            for filename in file_list:
                file_path = os.path.join(self.config_dir, filename)
                if os.path.isfile(file_path):
                    os.remove(file_path)
                    Log.info(f"Removed '{file_path}' file")

            os.rmdir(self.config_dir)
            Log.info(f"Removed '{self.config_dir}' directory")

        Log.info("Config purging finished")
