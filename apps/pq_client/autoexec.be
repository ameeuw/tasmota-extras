var app
var wd = tasmota.wd
import sys
if size(wd) sys.path().push(wd) end
print("pq_client/autoexec.be")
print(wd)
import powerquartier
import pq_credentials
import pq_accounts
if size(wd) sys.path().pop() end