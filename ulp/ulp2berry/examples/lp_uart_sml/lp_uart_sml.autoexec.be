print("target: {{buildTarget}}")
print("ULP architecture: {{ulpArch}}")
var app
var wd = tasmota.wd
import sys
if size(wd) sys.path().push(wd) end
print("{{projectName}}/autoexec.be")
print(wd)
import ulp2berry
import {{projectName}}
import {{projectName}}_config
if size(wd) sys.path().pop() end