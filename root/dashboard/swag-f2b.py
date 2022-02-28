import json
import sqlite3
import sys

f2bdb = "/config/fail2ban/fail2ban.sqlite3"
if sys.argv[1:]:
    f2bdb = sys.argv[1]

con = sqlite3.connect(f2bdb)
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
