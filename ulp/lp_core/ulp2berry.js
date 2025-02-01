const fs = require("fs");
const path = require("path");

function parseMapFile(mapFileContent, buildTarget) {
  var type = "FSM";
  var symbols = "";
  var symbols_keyed = {};
  for (line of mapFileContent) {
    if (line.includes("PROVIDE (ulp")) {
      let el = line.split("PROVIDE")[1];
      let prefix = el.replace(/[\(=]/g, "").split("0x")[0].trim();
      let suffix = el.replace(")", "").split("0x")[1];
      let address = null;
      let suffix_int = parseInt(suffix, 16);
      if (suffix_int > 0x60000000) {
        address = (suffix_int - 0x50000000) / 4; // Does somebody have a link to the docs?
      }
      symbols += "#" + el + " -> ULP.get_mem(" + address + ") \n";
      if (!symbols_keyed[suffix]) {
        symbols_keyed[suffix] = [];
      }
      symbols_keyed[suffix].push({
        prefix,
        suffix,
        address,
      });
    }
    if (line.includes("ulp_riscv_run")) {
      type = "RISCV";
    }
  }
  if (symbols.length != 0) {
    return {
      type,
      symbols:
        "# ULP type: " +
        type +
        "\n# Build target: " +
        buildTarget +
        "\n\n" +
        symbols,
      symbols_keyed,
    };
  }
  return { type, symbols: "", symbols_keyed: {} };
}

function parseBinSFile(sFileContent) {
  var binary = [];
  var words;
  for (line of sFileContent) {
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
    var _b64 = "";
    for (b of binary) {
      _b64 += String.fromCharCode(b);
    }
    return {
      length: words,
      binary64: btoa(_b64),
    };
  }
  return null;
}

function checkULPSDKConfig(file) {
  for (line of file) {
    let tokens = line.split("=");
    if (tokens[0] == "CONFIG_IDF_TARGET") {
      return tokens[1];
    }
  }
  return null;
}

function processULPFiles(directoryPath) {
  const files = fs.readdirSync(directoryPath);
  let buildTarget = null;
  let sFileContent = null;
  let mapFileContent = null;
  const readTemplate = process.argv.includes("-r");
  const saveTemplate = process.argv.includes("-s");
  const verbose = process.argv.includes("-v");
  const projectName = process.env.PROJECT_NAME || path.basename(directoryPath);
  if (files.includes("sdkconfig")) {
    console.log("Processing:", "sdkconfig");
    const sdkConfigFile = fs
      .readFileSync(path.join(directoryPath, "sdkconfig"), "utf8")
      .split(/\r\n|\n/);
    buildTarget = checkULPSDKConfig(sdkConfigFile);
  }

  if (files.includes("build")) {
    const buildFiles = fs.readdirSync(path.join(directoryPath, "build"));
    buildFiles.forEach((file) => {
      const buildFilePath = path.join(directoryPath, "build", file);

      if (file.endsWith(".bin.S")) {
        console.log("Processing:", file);
        sFileContent = fs.readFileSync(buildFilePath, "utf8").split(/\r\n|\n/);
      } else if (file.endsWith(".map")) {
        if (file.includes("bootloader") || buildFilePath.includes("esp-idf")) {
          return;
        }
        console.log("Processing:", file);
        mapFileContent = fs
          .readFileSync(buildFilePath, "utf8")
          .split(/\r\n|\n/);
      }
    });
  }

  if (sFileContent && mapFileContent) {
    const mapResult = parseMapFile(mapFileContent, buildTarget);
    const binaryResult = parseBinSFile(sFileContent);
    console.log(`Length of binary in bytes: ${binaryResult.length}`);

    if (verbose) {
      console.log(mapResult.symbols_keyed);
    } else {
      console.log(
        Object.values(mapResult.symbols_keyed)
          .flat()
          .filter((v) => {
            return v.address;
          })
      );
    }
    let template = null;
    if (readTemplate) {
      template = getBerryTemplateFile(process.argv[2]);
    } else {
      template = "";
      template += "import ULP \n";
      template +=
        "ULP.wake_period(0,1000 * 1000) # timer register 0 - every 1000 millisecs\n";
      template += 'c = bytes().fromb64("{{code_b64}}") \n';
      template += "ULP.load(c) \n";
      template += "ULP.run() \n";
    }

    const generatedBerryFile = generateBerryFile(
      mapResult,
      binaryResult,
      template
    );

    console.log(
      "Generated berry file.\nTo make sure to copy the entire file, run the script with the -v flag.\n"
    );
    if (generatedBerryFile) {
      if (verbose) {
        console.log(generatedBerryFile);
      } else {
        console.log(
          "! ALL LINES ARE CURTAILED TO 120 CHARACTERS ! \n!COPYING THIS CODE WILL MOST LIKELY NOT WORK!\n\n" +
            generatedBerryFile
              .split("\n")
              .map((line) => line.slice(0, 120))
              .join("\n")
        );
      }
      if (saveTemplate) {
        storeBerryFile(directoryPath, generatedBerryFile, projectName);
      }
    }
  }
}

function getBerryTemplateFile(directoryPath) {
  const files = fs.readdirSync(directoryPath);
  if (files.find((file) => file.endsWith(".be"))) {
    const berryFile = files.find((file) => file.endsWith(".be"));
    console.log("Processing:", berryFile);
    const berryFileContent = fs.readFileSync(
      path.join(directoryPath, berryFile),
      "utf8"
    );
    return berryFileContent;
  }
  return null;
}

function generateBerryFile(mapResult, binaryResult, template) {
  if (!mapResult || !binaryResult || !template) return;

  template = template.replace("{{code_b64}}", binaryResult.binary64);

  // Filter by address: not sure about the shifting and dividing by 4 in the parseMapFile
  // --> we filter by them being larger than 0x60000000
  const parseableMappings = Object.values(mapResult.symbols_keyed)
    .flat()
    .filter((v) => {
      return v.address;
    });

  parseableMappings.forEach((v) => {
    template = template.replace(new RegExp(`{{v.prefix}}`, "g"), v.address);
  });

  return template;
}

function storeBerryFile(directoryPath, berryFileContent, projectName) {
  const files = fs.readdirSync(directoryPath);
  if (files.includes("build")) {
    const buildFilePath = path.join(
      directoryPath,
      "build",
      `${projectName}.be`
    );
    fs.writeFileSync(buildFilePath, berryFileContent);
  }
}

processULPFiles(process.argv[2]);
