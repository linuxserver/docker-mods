import json
import sqlite3
import os

MOD_DASHBOARD_F2B_HOST_DB = "/var/lib/fail2ban/fail2ban.sqlite3"
if "MOD_DASHBOARD_F2B_HOST_DB" in os.environ:
    MOD_DASHBOARD_F2B_HOST_DB = os.environ['MOD_DASHBOARD_F2B_HOST_DB']

if not os.path.exists(MOD_DASHBOARD_F2B_HOST_DB):
    exit()

con = sqlite3.connect(MOD_DASHBOARD_F2B_HOST_DB)
cur = con.cursor()
results = cur.execute("""
    SELECT jails.name, 
    COUNT(bans.ip) AS bans,
    (SELECT DISTINCT bans.ip from bans where jails.name = bans.jail ORDER BY timeofban DESC) as last_ban,
    (SELECT DISTINCT bans.data from bans where jails.name = bans.jail ORDER BY timeofban DESC) as data
    FROM jails 
    LEFT JOIN bans ON jails.name=bans.jail 
    GROUP BY jails.name
    """).fetchall()
con.close()
formatted_results = [{
    "name": name,
    "bans": bans,
    "last_ban": last_ban,
    "data": json.dumps(json.loads(data), indent=4, sort_keys=True) if data else None
} for (name, bans, last_ban, data) in results]

output = json.dumps(formatted_results, sort_keys=True)
print(output)
