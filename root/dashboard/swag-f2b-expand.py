import json
import sqlite3
import sys
import os
from datetime import datetime
import pytz

if sys.argv[1:]:
    jail = sys.argv[1]
else:
    exit()

MOD_DASHBOARD_F2B_HOST_DB = "/var/lib/fail2ban/fail2ban.sqlite3"
MOD_DASHBOARD_F2B_MAX_LINES = 30
TZ='UTC'

if "MOD_DASHBOARD_F2B_HOST_DB" in os.environ:
    MOD_DASHBOARD_F2B_HOST_DB = os.environ['MOD_DASHBOARD_F2B_HOST_DB']
if "MOD_DASHBOARD_F2B_MAX_LINES" in os.environ:
    MOD_DASHBOARD_F2B_MAX_LINES = os.environ['MOD_DASHBOARD_F2B_MAX_LINES']
if "TZ" in os.environ:
    TZ = os.environ['TZ']

if not os.path.exists(MOD_DASHBOARD_F2B_HOST_DB):
    exit()

con = sqlite3.connect(MOD_DASHBOARD_F2B_HOST_DB)
cur = con.cursor()
results = cur.execute("SELECT DISTINCT timeofban, 1 as num, ip from bans where jail = '%s' ORDER BY timeofban DESC LIMIT %s" % (jail, MOD_DASHBOARD_F2B_MAX_LINES)).fetchall()
# results = cur.execute("SELECT * from bans where jail='sshd' limit 10").fetchall()
con.close()
formatted_results = [{
    "timeofban": datetime.fromtimestamp(timeofban, pytz.timezone(TZ)).strftime('%Y-%m-%d %H:%M:%S'),
    "num": num,
    "ip": ip
} for (timeofban, num, ip) in results]

output = json.dumps(formatted_results, sort_keys=True)
# output = results
print(output)
