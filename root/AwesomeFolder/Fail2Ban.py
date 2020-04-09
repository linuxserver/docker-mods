#!/usr/bin/env python3
import argparse
import collections
import datetime
import geoip2.database
import os
import requests

class Discord:
    def __init__(self, data, action):
        self.action = action
        self.base = "https://discordapp.com/api/webhooks/"
        self.data = data
        self.token = os.getenv('DISC_HOOK', "") # If not setting enviroment variables, edit this
        self.you = os.getenv('DISC_ME', "120970603556503552") # If not setting enviroment variables, edit this

    def create_payload(self):
        webhook = {
                "username":"Fail2Ban",
                "content": f"<@{self.you}>",
                "embeds": [{}]
                }
        webhook["embeds"][0]["author"] = {"name": "Fail2Ban"}
        webhook["embeds"][0]["timestamp"] = f"{datetime.datetime.utcnow()}"
        if "ban" in self.action.action:
            webhook["embeds"][0]["url"] =  f"https://db-ip.com/{self.data['ip']}"
            webhook["embeds"][0]["image"] = {"url": f"{self.data['map-img']}"}
            webhook["embeds"][0]["fields"] = [{}]
            webhook["embeds"][0]["fields"][0]["name"] = f":flag_{self.data['iso'].lower()}:"
            webhook["embeds"][0]["fields"][0]["value"] = self.data["city"] or self.data["name"]
            if self.action.action == "ban":
                webhook["embeds"][0]["fields"].append({"name": f"Map", "value": f"[Link]({self.data['map-url']})"})
                webhook["embeds"][0]["fields"].append({"name": f"Unban cmd", "value": f"fail2ban-client unban {self.data['ip']}"})
                webhook["embeds"][0]["title"] = f"New ban on `{self.action.jail}`"
                webhook["embeds"][0]["description"] = f"**{self.data['ip']}** got banned for `{self.action.time}` hours after `{self.action.fail}` tries"
                webhook["embeds"][0]["color"] = 16194076
            elif self.action.action == "unban":
                webhook["embeds"][0]["title"] = f"Revoked ban on `{self.action.jail}`"
                webhook["embeds"][0]["description"] = f"**{self.data['ip']}** is now unbanned"
                webhook["embeds"][0]["color"] = 845872
        elif self.action.action == "start":
            webhook["content"] = ""
            webhook["embeds"][0]["description"] = f"Started `{self.action.jail}`"
            webhook["embeds"][0]["color"] = 845872
        elif self.action.action == "stopped":
            webhook["content"] = ""
            webhook["embeds"][0]["description"] = f"Stopped `{self.action.jail}`"
            webhook["embeds"][0]["color"] = 16194076
        elif self.action.action == "test":
            webhook["content"] = ""
            webhook["embeds"][0]["description"] = f"I am working"
            webhook["embeds"][0]["color"] = 845872
        else:
            return None
        return webhook

    def send(self, payload):
        r = requests.post(url=f"{self.base}{self.token}", json=payload)

class Helpers:
    def __init__(self, ip):
        self.data = {"ip": ip}
        self.map_api = os.getenv('DISC_API', "") # If not setting enviroment variables, edit this
        self.reader = geoip2.database.Reader('/config/geoip2db/GeoLite2-City.mmdb')
        self.f2b()
        self.map()

    def f2b(self):
        r = self.reader.city(self.data['ip'])
        self.data["iso"] = r.country.iso_code
        self.data["name"] = r.country.name
        self.data["city"] = r.city.name
        self.data["lat"] = r.location.latitude
        self.data["lon"] = r.location.longitude


    def map(self):
        img_params={"center":f"{self.data['lat']},{self.data['lon']}", "size":"500,300", "key": self.map_api}
        img_r = requests.get('https://www.mapquestapi.com/staticmap/v5/map', params=img_params)
        self.data["map-img"] = img_r.url
        url_params={"center":f"{self.data['lat']},{self.data['lon']}", "size":"500,300"}
        url_r = requests.get('https://mapquest.com/', params=url_params)
        self.data["map-url"] = url_r.url

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Discord notifier for F2B')
    parser.add_argument('-a', '--action', help="Which F2B action triggered the script", required=True)
    parser.add_argument('-i', '--ip', help="ip which triggered the action", default="1.1.1.1")
    parser.add_argument('-j', '--jail', help="jail which triggered the action")
    parser.add_argument('-t', '--time', help="The time the action is valid")
    parser.add_argument('-f', '--fail', help="Amount of attempts done")

    args = parser.parse_args()

    data = Helpers(args.ip).data
    disc = Discord(data, args)
    if (payload := disc.create_payload()):
        disc.send(payload)
