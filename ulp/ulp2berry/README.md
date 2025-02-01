### ulp2berry nodejs script

This script is a nodejs variant of the parsing script available at the tasmota docs https://tasmota.github.io/docs/ULP/.
It is a bit more flexible and allows to read and write the berry file to the project directory.

Make sure you have nodejs installed. Then you can run the script from the project directory:
```
node ulp2berry.js
```

### ulp2berry docker image

#### Build
To build the docker image by hand, run:
```
docker build --no-cache -t ulp2berry .
```

#### Run
The `run_docker.sh` script will run the docker image and mount the current directory as `/project`.
You can set the project directory with the `-p` option.
You can set a alternative name for the project with the `-n` option.

Start an interactive session with the project directory mounted:
```
./run_docker.sh -d lp_uart_echo
```

If necessary, set the target to esp32c6:
```
idf.py set-target esp32c6
```

Build the project:
```
idf.py build
```

The `ulp2berry` script is aliased and has the following command line options:
-r: read the berry template file from the project directory
-w: write the berry file to the project directory
-v: verbose output

Generate the berry file:
```
ulp2berry -r -w
```

To get closest to the website ulp2berry script, you can use just `-v` option
```
ulp2berry -v
```
