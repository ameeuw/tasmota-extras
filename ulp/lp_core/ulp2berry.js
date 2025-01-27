const fs = require("fs");
const path = require("path");

var ulp_S_file, ulp_map_file, ulp_binary_length, ulp_build_target;

function parseMapFile() {
  var type = "FSM";
  var symbols = "";
  for (line of ulp_map_file) {
    if (line.includes("PROVIDE (ulp")) {
      let el = line.split("PROVIDE")[1];
      let suffix = el.replace(")", "").split("0x")[1];
      let address = (parseInt(suffix, 16) - 0x50000000) / 4;
      // console.log(el,suffix,address);
      symbols += "#" + el + " -> ULP.get_mem(" + address + ") \n";
    }
    if (line.includes("ulp_riscv_run")) {
      type = "RISCV";
    }
  }
  if (symbols.length != 0) {
    return (
      "# ULP type: " +
      type +
      "\n# Build target: " +
      ulp_build_target +
      "\n\n" +
      symbols
    );
  }
  return "";
}

function parseBinSFile() {
  var binary = [];
  var words;
  for (line of ulp_S_file) {
    if (line.startsWith(".byte")) {
      tokens = line.split(" ");
      for (token of tokens) {
        if (token.startsWith("0x")) {
          binary.push(parseInt(token.substring(2), 16));
        }
      }
    }
    if (line.startsWith(".word") || line.startsWith(".long")) {
      words = parseInt(line.split(" ")[1]);
    }
  }
  if (binary.length == words) {
    ulp_binary_length = words;
    var _b64 = "";
    for (b of binary) {
      _b64 += String.fromCharCode(b);
    }
    return btoa(_b64);
  }
}

function checkULPSDKConfig(file) {
  for (line of file) {
    let tokens = line.split("=");
    if (tokens[0] == "CONFIG_IDF_TARGET") {
      ulp_build_target = tokens[1];
    }
  }
}

function parseULPFiles() {
  let map_string = parseMapFile();
  let binary64 = parseBinSFile();
  var output = map_string + "\n";
  output += "# You can paste the following snippet to the berry console: \n";
  output += "# Length of binary in bytes: " + ulp_binary_length + "\n";
  output += "import ULP \n";
  output +=
    "ULP.wake_period(0,1000 * 1000) # timer register 0 - every 1000 millisecs\n";
  output += 'c = bytes().fromb64("' + binary64 + '") \n';
  output += "ULP.load(c) \n";
  output += "ULP.run() \n";
  console.log(output);
}

function checkULPBuildFiles() {
  if (ulp_S_file && ulp_map_file) {
    parseULPFiles();
  }
}

function processULPFiles(directoryPath) {
  // Read all files in the directory
  const files = fs.readdirSync(directoryPath);

  if (files.includes("sdkconfig")) {
    console.log("Processing:", "sdkconfig");
    const sdkConfigFile = fs
      .readFileSync(path.join(directoryPath, "sdkconfig"), "utf8")
      .split(/\r\n|\n/);
    checkULPSDKConfig(sdkConfigFile);
  }

  if (files.includes("build")) {
    const buildFiles = fs.readdirSync(path.join(directoryPath, "build"));
    buildFiles.forEach((file) => {
      const buildFilePath = path.join(directoryPath, "build", file);

      if (file.endsWith(".bin.S")) {
        console.log("Processing:", file);
        ulp_S_file = fs.readFileSync(buildFilePath, "utf8").split(/\r\n|\n/);
        checkULPBuildFiles();
      } else if (file.endsWith(".map")) {
        if (file.includes("bootloader") || buildFilePath.includes("esp-idf")) {
          return;
        }
        console.log("Processing:", file);
        ulp_map_file = fs.readFileSync(buildFilePath, "utf8").split(/\r\n|\n/);
        checkULPBuildFiles();
      }
    });
  }
}

processULPFiles(process.argv[2]);
