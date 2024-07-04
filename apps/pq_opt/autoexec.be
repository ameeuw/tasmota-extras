var wd = tasmota.wd
import sys
if size(wd) sys.path().push(wd) end
print("pq_opt/autoexec.be")
print(wd)
import pq_opt
if size(wd) sys.path().pop() end