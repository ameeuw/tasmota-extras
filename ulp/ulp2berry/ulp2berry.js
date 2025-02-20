const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const { Liquid } = require("liquidjs");

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
        sFileContent = fs.readFileSync(filePath, "utf8");
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
    let type = "fsm";
    const symbols = {};

    for (const line of mapFileContent) {
      if (line.match(/0x[0-9a-fA-F]+\s+ulp_/)) {
        let [address, symbol] = line.trim().split(/\s+/);
        let addressInt = parseInt(address.replace("0x", ""), 16);
        let shifted = false;

        if (addressInt > 0x50000000) {
          addressInt = (addressInt - 0x50000000) / 4; // Word width. When getting address they jump one every 4 bytes
          shifted = true;
        }
        symbols[symbol] = {
          symbol,
          address,
          addressInt,
          shifted,
        };
      }

      if (line.includes("ulp_riscv_run")) {
        type = "riscv";
      } else if (line.includes("ulp_lp_core_run")) {
        type = "lp_core";
      }
    }

    return { type, symbols };
  }

  parseBinSFile(sFileContent) {
    // Extract all byte values using regex
    const bytePattern = /\.byte\s+((?:0x[0-9a-f]{2},\s*)*0x[0-9a-f]{2})/g;
    const bytes = [];

    let match;
    while ((match = bytePattern.exec(sFileContent)) !== null) {
      // Split the byte string and convert each hex value to a number
      const byteValues = match[1].split(",").map((b) => parseInt(b.trim(), 16));
      bytes.push(...byteValues);
    }

    // Look for word length at the end of the file
    const lengthMatch = sFileContent.match(/\.word\s+(\d+)\s*$/);
    if (lengthMatch) {
      const expectedLength = parseInt(lengthMatch[1], 10);
      if (bytes.length !== expectedLength) {
        throw new Error(
          `Length mismatch: Expected ${expectedLength} bytes, got ${bytes.length} bytes`
        );
      }
    }

    // Convert byte array to Uint8Array
    const uint8Array = new Uint8Array(bytes);

    // Convert to base64
    let binary = "";
    uint8Array.forEach((byte) => {
      binary += String.fromCharCode(byte);
    });

    return {
      length: bytes.length,
      // binary64: Buffer.from(bytes).toString("base64"),
      base64: btoa(binary),
    };
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
    this.engine = new Liquid();
  }

  getDefaultTemplate() {
    return [
      "import ULP",
      "ULP.wake_period(0,1000 * 1000) # timer register 0 - every 1000 millisecs",
      'c = bytes().fromb64("{{binary.base64}}")',
      "ULP.load(c)",
      "ULP.run()",
    ].join("\n");
  }

  async generateFile(
    payload,
    template = this.getDefaultTemplate(),
    verbose = false
  ) {
    const liquidTemplate = this.engine.parse(template);
    const berryContent = this.engine.render(liquidTemplate, payload);

    if (verbose) {
      console.log(berryContent);
    }

    return berryContent;
  }
}

class TAppBuilder {
  constructor(projectName) {
    this.projectName = projectName;
    this.engine = new Liquid();
  }

  async build(directoryPath, payload) {
    const buildPath = path.join(directoryPath, "build", "berry");

    try {
      // Read relevant Berry files (starting with the project name)

      const files = fs.readdirSync(buildPath);
      const berryFiles = files.filter(
        (file) =>
          (file.startsWith(this.projectName) && file.endsWith(".be")) ||
          file.includes("ulp2berry")
      );

      console.log(
        `Found ${berryFiles.length} relevant Berry files: "${berryFiles.join(
          '", "'
        )}"`
      );

      const berryFileContents = berryFiles.map((file) => {
        return {
          name: file,
          content: fs.readFileSync(path.join(buildPath, file), "utf8"),
        };
      });

      // Get default autoexec file if not present
      if (!berryFileContents.find((file) => file.name.includes("autoexec"))) {
        berryFileContents.push({
          name: "autoexec.be",
          content: this.getDefaultAutoexec(),
        });
      }

      // Create TAPP structure
      const tappPath = path.join(buildPath, `${this.projectName}-tapp`);
      if (fs.existsSync(tappPath)) {
        fs.rmSync(tappPath, { recursive: true });
      }

      // Create directory and write files
      fs.mkdirSync(tappPath);

      for (const file of berryFileContents) {
        console.log(file.name);
        if (file.name.includes("autoexec")) {
          file.name = "autoexec.be";
        }
        const liquidTemplate = this.engine.parse(file.content);
        const berryContent = await this.engine.render(liquidTemplate, payload);
        fs.writeFileSync(path.join(tappPath, file.name), berryContent);
      }

      // Create ZIP archive
      const tappFile = path.join(
        buildPath,
        `${this.projectName}-${payload.buildTarget}-${payload.ulpArch}.tapp`
      );
      execSync(`zip -0 -j "${tappFile}" "${tappPath}"/*`);
    } catch (error) {
      throw new Error(
        `Error building TAPP: ${error.message}\n` +
          `To build a Tasmota App for a ULP module there needs to be a build folder with ${this.projectName}.be`
      );
    }
  }

  getDefaultAutoexec() {
    return `print("target: {{buildTarget}}")
print("ULP architecture: {{ulpArch}}")
var app
var wd = tasmota.wd
import sys
if size(wd) sys.path().push(wd) end
print("{{projectName}}/autoexec.be")
print(wd)
import {{projectName}}
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

  async run() {
    try {
      const ulpData = this.processor.process();
      const payload = this.buildPayload(ulpData);

      if (this.args.has("-t")) {
        await this.tappBuilder.build(this.args.getDirectory(), payload);
      } else {
        const templates = this.args.has("-r")
          ? this.readBerryTemplates(this.args.getDirectory())
          : [this.generator.getDefaultTemplate()];

        const buildPath = path.join(this.args.getDirectory(), "build", "berry");
        if (this.args.has("-w")) {
          if (fs.existsSync(buildPath)) {
            fs.rmSync(buildPath, { recursive: true });
          }
          // Create directory and write files
          fs.mkdirSync(buildPath);
        }

        for (const template of templates) {
          const berryContent = await this.generator.generateFile(
            payload,
            template.content,
            this.args.has("-v")
          );

          if (this.args.has("-w")) {
            this.writeBerryFile(berryContent, buildPath, template.name);
          }
        }
      }
    } catch (error) {
      console.error("Error:", error.message);
      process.exit(1);
    }
  }

  readBerryTemplates(directoryPath) {
    const files = fs.readdirSync(directoryPath);
    const berryFiles = files.filter((file) => file.endsWith(".be"));

    const ulp2berryTemplates = fs.readdirSync(
      path.join(__dirname, "templates")
    );
    const templateFiles = ulp2berryTemplates.filter((file) =>
      file.includes("ulp2berry")
    );

    const berryTemplates = [];
    templateFiles.forEach((file) => {
      const content = fs.readFileSync(
        path.join(__dirname, "templates", file),
        "utf8"
      );
      berryTemplates.push({
        name: file,
        content,
      });
    });

    berryFiles.forEach((file) => {
      const content = fs.readFileSync(path.join(directoryPath, file), "utf8");
      berryTemplates.push({
        name: file,
        content,
      });
    });

    console.log(berryTemplates.map((t) => t.name).join("\n"));

    return berryTemplates;
  }

  writeBerryFile(content, directoryPath, templateName) {
    const filePath = path.join(directoryPath, templateName);
    fs.writeFileSync(filePath, content);
    console.log(`Berry file written to: ${filePath}`);
  }

  buildPayload(ulpData) {
    const { mapResult, binaryResult, mainHResult } = ulpData;

    if (!mapResult || !binaryResult) {
      throw new Error("Missing required data for Berry file generation");
    }

    console.log(`
      ULP extracted payload structure:
      =================================
      {
        "symbols": {
          binary: {
          "base64": string,
          "length": number
          },
          symbols: {
            [symbol]: {
              "type": "int" | "float" | "string" | "bool",
              "length": number,
              "address": string,
            }
          },
          buildTarget: string,
          ulpArch: "fsm" | "riscv" | "lp_core",
          projectName: string,
      }
      =================================`);

    // Transform the data into the required structure
    return {
      binary: binaryResult,
      symbols: Object.entries(mapResult.symbols).reduce((acc, [key, value]) => {
        // Get the type and length from mainHResult if available
        const varInfo = mainHResult[key] || { type: "unknown", length: 1 };

        acc[key] = {
          type: varInfo.type,
          length: varInfo.length,
          address: value.addressInt,
        };
        return acc;
      }, {}),
      buildTarget: ulpData.buildTarget,
      ulpArch: mapResult.type,
      projectName: this.projectName,
    };
  }
}

// Run the application
const app = new App();
app.run();
