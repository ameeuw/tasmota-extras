var app
var wd = tasmota.wd
import sys
if size(wd) sys.path().push(wd) end
print("pq_app/autoexec.be")
print(wd)
import pq_app
app = pq_app.PqApp()
if size(wd) sys.path().pop() end