const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const liquid = require("liquidjs");

class Args {
  constructor(args = process.argv.slice(2)) {
    this.args = args;
    this.flags = new Set();
    this.params = [];

    this.parse();
  }

  parse() {
    this.args.forEach((arg) => {
      if (arg.startsWith("-")) {
        this.flags.add(arg);
      } else {
        this.params.push(arg);
      }
    });
  }

  has(flag) {
    return this.flags.has(flag);
  }

  getDirectory() {
    return this.params[0];
  }

  validateInput() {
    if (!this.getDirectory()) {
      console.error("Error: Directory path is required");
      this.showUsage();
      process.exit(1);
    }
  }

  showUsage() {
    console.log(`
Usage: node ulp2berry.js [options] <directory>

Options:
  -t           Build TAPP package
  -v           Show verbose output
  -r           Read Berry template file
  -w           Write template file
  
Example:
  node ulp2berry.js -v ./my-project
`);
  }
}

class ULPProcessor {
  constructor(directoryPath) {
    this.directoryPath = directoryPath;
    this.buildPath = path.join(directoryPath, "build");
  }

  process() {
    const buildTarget = this.getBuildTarget();
    const { sFileContent, mapFileContent, lpCoreMainHContent } =
      this.readBuildFiles();

    if (!sFileContent || !mapFileContent) {
      throw new Error("Required build files not found");
    }

    return {
      mapResult: this.parseMapFile(mapFileContent),
      binaryResult: this.parseBinSFile(sFileContent),
      buildTarget,
      mainHResult: this.parseCoreMainHFile(lpCoreMainHContent),
    };
  }

  getBuildTarget() {
    const sdkConfigPath = path.join(this.directoryPath, "sdkconfig");
    if (!fs.existsSync(sdkConfigPath)) {
      return null;
    }

    const content = fs.readFileSync(sdkConfigPath, "utf8").split(/\r\n|\n/);
    return this.checkULPSDKConfig(content);
  }

  readBuildFiles() {
    if (!fs.existsSync(this.buildPath)) {
      throw new Error("No build folder found");
    }

    const buildFiles = fs.readdirSync(this.buildPath);
    let sFileContent = null;
    let mapFileContent = null;
    let lpCoreMainHContent = null;

    buildFiles.forEach((file) => {
      const filePath = path.join(this.buildPath, file);
      if (file.endsWith(".bin.S")) {
        sFileContent = fs.readFileSync(filePath, "utf8").split(/\r\n|\n/);
      } else if (file.endsWith(".map") && !file.includes("bootloader")) {
        mapFileContent = fs.readFileSync(filePath, "utf8").split(/\r\n|\n/);
      }
    });

    const lpCoreMainHPath = path.join(
      this.buildPath,
      "esp-idf",
      "main",
      "lp_core_main",
      "lp_core_main.h"
    );
    if (fs.existsSync(lpCoreMainHPath)) {
      lpCoreMainHContent = fs.readFileSync(lpCoreMainHPath, "utf8");
    }

    return { sFileContent, mapFileContent, lpCoreMainHContent };
  }

  parseMapFile(mapFileContent) {
    let type = "FSM";
    const symbols_keyed = {};

    for (const line of mapFileContent) {
      if (line.match(/0x[0-9a-fA-F]+\s+ulp_/)) {
        let [address, symbol] = line.trim().split(/\s+/);
        let addressInt = parseInt(address.replace("0x", ""), 16);
        let shifted = false;

        if (addressInt > 0x50000000) {
          addressInt = (addressInt - 0x50000000) / 4; // Word width. When getting address they jump one every 4 bytes
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

    return { type, symbols_keyed };
  }

  parseBinSFile(sFileContent) {
    const binary = [];
    let words;

    for (const line of sFileContent) {
      if (line.startsWith(".byte")) {
        const tokens = line.split(" ");
        for (const token of tokens) {
          if (token.startsWith("0x")) {
            binary.push(parseInt(token.substring(2), 16));
          }
        }
      }
      if (line.startsWith(".word") || line.startsWith(".long")) {
        words = parseInt(line.split(" ")[1]);
      }
    }

    if (binary.length === words) {
      let b64 = "";
      for (const b of binary) {
        b64 += String.fromCharCode(b);
      }
      return {
        length: words,
        binary64: Buffer.from(b64).toString("base64"),
      };
    }
    return null;
  }

  checkULPSDKConfig(file) {
    for (const line of file) {
      const tokens = line.split("=");
      if (tokens[0] === "CONFIG_IDF_TARGET") {
        return tokens[1].replace(/"/g, "");
      }
    }
    return null;
  }

  parseCoreMainHFile(fileContent) {
    if (!fileContent) return {};

    const vars =
      fileContent
        .match(/extern uint32_t (ulp_\w+)(?:\[(\d+)\])?;/g)
        ?.reduce((acc, line) => {
          const [_, name, len] = line.match(/(ulp_\w+)(?:\[(\d+)\])?;/);
          const type = name.match(/ulp_(int|float|string|bool)_/)
            ? name.match(/ulp_(int|float|string|bool)_/)[1]
            : "unknown";
          return {
            ...acc,
            [name]: {
              type,
              length: len ? parseInt(len) : 1,
            },
          };
        }, {}) || {};

    return vars;
  }
}

class BerryGenerator {
  constructor(projectName) {
    this.projectName = projectName;
    this.engine = liquid({
      strict_filters: true,
    });
  }

  getDefaultTemplate() {
    return [
      "import ULP",
      "ULP.wake_period(0,1000 * 1000) # timer register 0 - every 1000 millisecs",
      'c = bytes().fromb64("{{code_b64}}")',
      "ULP.load(c)",
      "ULP.run()",
    ].join("\n");
  }

  generateFile(ulpData, template = this.getDefaultTemplate(), verbose = false) {
    const liquidTemplate = this.engine.parse(template);
    const berryContent = this.generateContent(ulpData, template);

    console.log("\nGenerated berry file.");
    console.log(
      "To make sure to copy the entire file, run the script with the -v flag.\n"
    );

    if (verbose) {
      console.log(berryContent);
    } else {
      this.printTruncated(berryContent);
    }

    return berryContent;
  }

  generateContent(ulpData, template) {
    const { mapResult, binaryResult, mainHResult } = ulpData;

    if (!mapResult || !binaryResult || !template) {
      throw new Error("Missing required data for Berry file generation");
    }

    // Replace binary content
    template = template.replace("{{code_b64}}", binaryResult.binary64);

    // Replace symbol mappings
    const parseableMappings = Object.values(mapResult.symbols_keyed)
      .flat()
      .filter((v) => v.shifted);

    parseableMappings.forEach((v) => {
      template = template.replace(
        new RegExp(`{{${v.symbol}}}`, "g"),
        v.addressInt
      );
    });

    // Replace length mappings
    const lengthMappings = Object.entries(mainHResult).map(([key, value]) => ({
      symbol: `${key}_length`,
      length: value.length,
    }));

    lengthMappings.forEach((v) => {
      template = template.replace(new RegExp(`{{${v.symbol}}}`, "g"), v.length);
    });

    // Check for text and replace it with the symbol

    return template;
  }

  printTruncated(content) {
    console.log(
      "! ALL LINES ARE CURTAILED TO 120 CHARACTERS !\n" +
        "!COPYING THIS CODE WILL MOST LIKELY NOT WORK!\n\n" +
        content
          .split("\n")
          .map((line) => line.slice(0, 120))
          .join("\n")
    );
  }
}

class TAppBuilder {
  constructor(projectName) {
    this.projectName = projectName;
  }

  build(directoryPath, ulpData) {
    const buildPath = path.join(directoryPath, "build");
    const { mapResult, buildTarget } = ulpData;

    try {
      // Read the Berry file
      const berryFileContent = fs.readFileSync(
        path.join(buildPath, `${this.projectName}.be`),
        "utf8"
      );

      // Create template
      const template = this.createTAppTemplate(buildTarget, mapResult.type);

      // Create TAPP structure
      const tappPath = path.join(buildPath, `${this.projectName}-tapp`);
      if (fs.existsSync(tappPath)) {
        fs.rmSync(tappPath, { recursive: true });
      }

      // Create directory and write files
      fs.mkdirSync(tappPath);
      fs.writeFileSync(
        path.join(tappPath, `${this.projectName}.be`),
        berryFileContent
      );
      fs.writeFileSync(path.join(tappPath, "autoexec.be"), template);

      // Create ZIP archive
      const tappFile = path.join(
        buildPath,
        `${this.projectName}-${buildTarget}-${mapResult.type}.tapp`
      );
      execSync(`zip -0 -j "${tappFile}" "${tappPath}"/*`);
    } catch (error) {
      throw new Error(
        `Error building TAPP: ${error.message}\n` +
          `To build a Tasmota App for a ULP module there needs to be a build folder with ${this.projectName}.be`
      );
    }
  }

  createTAppTemplate(buildTarget, ulpArch) {
    return `print("target: ${buildTarget}")
print("ULP architecture: ${ulpArch}")
var app
var wd = tasmota.wd
import sys
if size(wd) sys.path().push(wd) end
print("${this.projectName}/autoexec.be")
print(wd)
import ${this.projectName}
if size(wd) sys.path().pop() end`;
  }
}

class App {
  constructor() {
    this.args = new Args();
    this.args.validateInput();

    const directoryPath = this.args.getDirectory();
    this.projectName = process.env.PROJECT_NAME || path.basename(directoryPath);

    this.processor = new ULPProcessor(directoryPath);
    this.generator = new BerryGenerator(this.projectName);
    this.tappBuilder = new TAppBuilder(this.projectName);
  }

  run() {
    try {
      const ulpData = this.processor.process();

      if (this.args.has("-t")) {
        this.tappBuilder.build(this.args.getDirectory(), ulpData);
      } else {
        console.log(ulpData);
        const template = this.args.has("-r")
          ? this.readBerryTemplate(this.args.getDirectory())
          : this.generator.getDefaultTemplate();

        const berryContent = this.generator.generateFile(
          ulpData,
          template,
          this.args.has("-v")
        );

        if (this.args.has("-w")) {
          this.writeBerryFile(this.args.getDirectory(), berryContent);
        }
      }
    } catch (error) {
      console.error("Error:", error.message);
      process.exit(1);
    }
  }

  readBerryTemplate(directoryPath) {
    const files = fs.readdirSync(directoryPath);
    const berryFile = files.find((file) => file.endsWith(".be"));

    if (berryFile) {
      console.log("Processing:", berryFile);
      return fs.readFileSync(path.join(directoryPath, berryFile), "utf8");
    }

    return null;
  }

  writeBerryFile(directoryPath, content) {
    const buildPath = path.join(directoryPath, "build");
    if (fs.existsSync(buildPath)) {
      const filePath = path.join(buildPath, `${this.projectName}.be`);
      fs.writeFileSync(filePath, content);
      console.log(`Berry file written to: ${filePath}`);
    }
  }
}

// Run the application
const app = new App();
app.run();
