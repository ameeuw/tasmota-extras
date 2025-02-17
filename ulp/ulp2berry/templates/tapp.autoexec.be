# This is the autoexec.be template file for ULP2Berry projects
# It is executed automatically when the ULP program starts

# Print build information
print("target: {{buildTarget}}")
print("ULP architecture: {{ulpArch}}")

# Initialize variables
var app                          # Main application instance
var wd = tasmota.wd             # Get working directory from Tasmota

# Add working directory to system path if it exists
import sys
if size(wd) sys.path().push(wd) end

# Print project information and working directory
print("{{projectName}}/autoexec.be")
print(wd)

# Import required modules
import ulp2berry                 # Import the ULP2Berry framework
import {{projectName}}           # Import the project-specific module

# Remove working directory from path after imports
if size(wd) sys.path().pop() end 