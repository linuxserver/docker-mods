#!/usr/bin/env python3
import requests

base = "https://discordapp.com/api/webhooks/"
token = os.getenv('DISC_HOOK', False)
you = os.getenv('DISC_ME', False)

content = f"<@{you}> "
message = "The fail2ban to discord mod is deprecated. Please remove it from your container"

webhook = {
    "username":"Fail2Ban",
    "content": content + message if you else message
    }

if token:
    requests.post(url=f"{base}{token}", json=webhook)

