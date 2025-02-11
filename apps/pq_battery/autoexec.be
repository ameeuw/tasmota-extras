var app
var wd = tasmota.wd
import sys
if size(wd) sys.path().push(wd) end
print("pq_battery/autoexec.be")
print(wd)
if size(wd) sys.path().pop() end