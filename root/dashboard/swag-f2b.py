import json
import sqlite3


con = sqlite3.connect("/config/fail2ban/fail2ban.sqlite3")
cur = con.cursor()
results = cur.execute("SELECT jails.name, COUNT(bans.ip) AS bans FROM jails LEFT JOIN bans ON jails.name=bans.jail GROUP BY jails.name").fetchall()
con.close()
output = json.dumps({k:v for (k,v) in results}, sort_keys=True)
print(output)
