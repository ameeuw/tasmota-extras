const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function parseMapFile(mapFileContent, buildTarget) {
  var type = "FSM";
  var symbols_keyed = {};
  for (line of mapFileContent) {
    if (line.match(/0x[0-9a-fA-F]+\s+ulp_/)) {
      let [address, symbol] = line.trim().split(/\s+/);
      let addressInt = parseInt(address.replace("0x", ""), 16);
      let shifted = false;
      if (addressInt > 0x50000000) {
        addressInt = (addressInt - 0x50000000) / 4; // TODO: find docs for the address shift
        shifted = true;
      }
      if (!symbols_keyed[address]) {
        symbols_keyed[address] = [];
      }
      symbols_keyed[address].push({
        symbol,
        address,
        addressInt,
        shifted,
      });
    }
    if (line.includes("ulp_riscv_run")) {
      type = "RISCV";
    } else if (line.includes("ulp_lp_core_run")) {
      type = "LP_CORE";
    }
  }
  return {
    type,
    symbols_keyed,
  };
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
      return tokens[1].replace(/"/g, "");
    }
  }
  return null;
}

function processULPFiles(directoryPath) {
  const files = fs.readdirSync(directoryPath);
  let buildTarget = null;
  let sFileContent = null;
  let mapFileContent = null;
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
  } else {
    console.error("No build folder found");
    return;
  }

  if (sFileContent && mapFileContent) {
    const mapResult = parseMapFile(mapFileContent, buildTarget);
    const binaryResult = parseBinSFile(sFileContent);

    return {
      mapResult,
      binaryResult,
      buildTarget,
    };
  }
}

function getAndStoreBerryFile(directoryPath) {
  const projectName = process.env.PROJECT_NAME || path.basename(directoryPath);
  const readTemplate = process.argv.includes("-r");
  const writeTemplate = process.argv.includes("-w");
  const verbose = process.argv.includes("-v");
  const { mapResult, binaryResult, buildTarget } =
    processULPFiles(directoryPath);
  console.log("\nResults:\n");

  console.log(
    `Binary: "${mapResult.type}" type (${binaryResult.length} bytes)`
  );

  console.log("Symbol mappings:");
  if (verbose) {
    console.log(mapResult.symbols_keyed);
  } else {
    console.log(
      Object.values(mapResult.symbols_keyed)
        .flat()
        .filter((v) => {
          return v.shifted;
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
    "\nGenerated berry file.\nTo make sure to copy the entire file, run the script with the -v flag.\n"
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
    if (writeTemplate) {
      storeBerryFile(directoryPath, generatedBerryFile, projectName);
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
      return v.shifted;
    });

  parseableMappings.forEach((v) => {
    template = template.replace(
      new RegExp(`{{${v.symbol}}}`, "g"),
      v.addressInt
    );
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

function processBerryFiles(directoryPath) {
  const { mapResult, binaryResult, buildTarget } =
    processULPFiles(directoryPath);
  const files = fs.readdirSync(directoryPath);
  const readTemplate = process.argv.includes("-r");
  const writeTemplate = process.argv.includes("-w");
  const verbose = process.argv.includes("-v");
  const projectName = process.env.PROJECT_NAME || path.basename(directoryPath);

  console.log("Build target:", buildTarget);
  console.log("ULP architecture:", mapResult.type);
  console.log("Binary size:", binaryResult.length);

  let template = null;
  if (readTemplate) {
    template = getBerryTemplateFile(process.argv[2]);
  } else {
    template = `print("target: {{BUILD_TARGET}}")
print("ULP architecture: {{ULP_ARCH}}")
var app
var wd = tasmota.wd
import sys
if size(wd) sys.path().push(wd) end
print("{{PROJECT_NAME}}/autoexec.be")
print(wd)
import {{PROJECT_NAME}}
if size(wd) sys.path().pop() end`;
  }

  const parseableMappings = [
    { prefix: "PROJECT_NAME", value: projectName },
    { prefix: "BUILD_TARGET", value: buildTarget },
    { prefix: "ULP_ARCH", value: mapResult.type },
  ];
  parseableMappings.forEach((v) => {
    template = template.replace(new RegExp(`{{${v.prefix}}}`, "g"), v.value);
  });

  if (files.includes("build")) {
    try {
      const buildPath = path.join(directoryPath, "build");
      const berryFileContent = fs.readFileSync(
        path.join(buildPath, `${projectName}.be`),
        "utf8"
      );

      if (writeTemplate) {
        const tappPath = path.join(buildPath, `${projectName}-tapp`);
        if (fs.existsSync(tappPath)) {
          fs.rmSync(tappPath, { recursive: true });
        }

        fs.mkdirSync(tappPath);
        fs.writeFileSync(
          path.join(tappPath, `${projectName}.be`),
          berryFileContent
        );
        const tappFile = path.join(
          buildPath,
          `${projectName}-${buildTarget}-${mapResult.type}.tapp`
        );
        fs.writeFileSync(path.join(tappPath, `autoexec.be`), template);
        execSync(`zip -0 -j "${tappFile}" "${tappPath}"/*`);
        // fs.rmSync(tappPath, { recursive: true });
      }
    } catch (e) {
      console.error(
        `Error reading berry file - to build a Tasmota App for a ulp module there needs to be a build folder with a <env.PROJECT_NAME>.be ("${projectName}.be")`
      );
      console.error(e);
    }
  }
}

const buildTapp = process.argv.includes("-t");

if (buildTapp) {
  processBerryFiles(process.argv[2]);
} else {
  getAndStoreBerryFile(process.argv[2]);
}
