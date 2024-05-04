from esp32_ulp import src_to_binary_ext, preprocess
import ubinascii, sys

if (len(sys.argv) == 1):
    print("Please specify a project name.")
    sys.exit()

project_name = sys.argv[1]
print('Assembling project "' + project_name + '":\n')
ulpSourcePath = "examples/" + project_name + "/" + project_name + ".s"
berrySourcePath = "examples/" + project_name + "/" + project_name + ".be"

# Load ULP source code
print('1. Loading ULP source code from "' + ulpSourcePath + '"')
ulpSourceFile = open (ulpSourcePath, "r")
ulpSource = ulpSourceFile.read()
ulpSourceFile.close()

# Assemble ULP source code
print("2. Assembling ULP source code")
source = preprocess(ulpSource)
binary, addrs_syms = src_to_binary_ext(ulpSource, cpu="esp32")

# Load Berry source code
print('3. Loading Berry source code from "' + berrySourcePath + '"')
berrySourceFile = open (berrySourcePath, "r")
berrySource = berrySourceFile.read()
berrySourceFile.close()

# Replace symbols in Berry source code
print("4. Replacing symbols in Berry source code:")
for address, symbol in addrs_syms:
  print('\t{{%s}} --> %s' % (symbol, str(address)))
  berrySource = berrySource.replace("{{" + symbol + "}}", str(address))

# Base64 encode binary and paste into Berry source code
code_b64 = ubinascii.b2a_base64(binary).decode('utf-8')[:-1]
berrySource = berrySource.replace("{{code_b64}}", code_b64)


berryExportPath = "dist/" + project_name + ".be"
# Export final Berry source code
print('5. Exporting final Berry source code to "' + berryExportPath + '"')
file = open (berryExportPath, "w")
file.write(berrySource)
file.close()