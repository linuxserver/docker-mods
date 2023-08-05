import os
from uptime_kuma_api import UptimeKumaApi, MonitorType

print("Hello World")

URL = os.environ['HOME']
USERNAME = os.environ['HOME']
PASSWORD = os.environ['HOME']


with UptimeKumaApi('INSERT_URL') as api:
    api.login(USERNAME, PASSWORD)

    result = api.add_monitor(type=MonitorType.HTTP, name="Google", url="https://google.com")
    print(result)