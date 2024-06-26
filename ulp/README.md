Tasmota Berry ULP


### Install micropython and ulp environment
```sh
brew install micropython
micropython
import mip
mip.install('github:micropython/micropython-esp32-ulp')
```


*Not necessary anymore since https://github.com/micropython/micropython-esp32-ulp/pull/98*
Add the modified `src_to_binary` (`src_to_binary_ext`) to  the "__init__.py" to hand out the symbol addresses as well:
```python
def src_to_binary_ext(src, cpu):
    assembler = Assembler(cpu)
    src = preprocess(src)
    assembler.assemble(src, remove_comments=False)  # comments already removed by preprocessor
    garbage_collect('before symbols export')
    addrs_syms = assembler.symbols.export()
    text, data, bss_len = assembler.fetch()
    return make_binary(text, data, bss_len), addrs_syms
```

On MacOS the file is located in the "~/.micropython/lib" dir.

### Fill preprocessor database

Get .h files for the specific processor from here: https://github.com/espressif/esp-idf/blob/master/components/soc
Download full folder using: https://download-directory.github.io
Copy to dir, unzip and rename to "soc"

Choose the chip (e.g. "esp32") and fill the DB
```sh
micropython -m esp32_ulp.parse_to_db soc/esp32/include/soc/*.h
```

Help on how to load into defines database: https://github.com/micropython/micropython-esp32-ulp/blob/master/docs/preprocess.rst

### Build binary

`from esp32_ulp import src_to_binary, preprocess`

You need to call the preprocessor using `source = preprocess(source)` before translating the source to binary `binary = src_to_binary(source, cpu="esp32")`
Ready made counter example:

Compile and build an example:
```sh
micropython examples/ulp_hall.py
```

https://github.com/Staars/berry-examples/blob/main/ulp_examples/ulp_gpio_wake.py


### `assemble.py` convenience script

I have put together a convenience script that takes care of assembling the code and stitching together the necessary register directives in the python code.

This script allows you to write your assembler and berry scripts separately, make use of code formatting, and have a generally cleaner deployment workflow.

A comprehensive example is given in `examples/ulp_pulse`. It contains the `.s` assembler script that registers pulses, pulse-lengths, min- & max-times and stores them in available registers.
The corresponding berry script initialises the ULP code with the available settings, reads the required variables and provides them as `teleperiod` and a web-values.
A convenenince helper is the use of templating curly braces which get replaced in the `assemble.py` script with the corresponding register addresses once the code has been compiled. As an example: in the `ulp_pulse.s` the global `edge_count` is defined as `long` which is then only available as a register address after compilation. In the `init()` of `ulp_pulse.be` the section with the curly braces in `self.reg_edge_count = {{edge_count}}` is replaced with the corresponding register address.

### Docker container

There is Dockerfile that build a docker image as part of this repository which includes all the above steps (install micropython, install ulp package, build the defines database).
This image can be used to run the assemble script without any hassle.

To build the included `ulp_pulse` example a "run_assemble.sh" script is included:
```sh
#!/bin/sh

# First mount: mount the assemble script
# Second mount: mount the project directory for input
# Third mount: mount the dist directory for output

docker run -it --rm \
-v "$PWD/assemble.py":/assemble.py \
-v "$PWD/examples/ulp_pulse":/ulp_pulse \
-v "$PWD/dist":/dist \
ameeuw/ulp \
micropython assemble.py ulp_pulse
```

From the `ulp` directory we run the docker image `ameeuw/ulp` and mount the `assemble.py` script on the root level, we mount the project directory for ulp_pulse (from `examples/ulp_pulse`) as `ulp_pulse` (project_name) on the root level, and finally mount the `dist` directory on the root level.
We then run the mounted `assemble.py` script using the `micropython` in the docker image and provide the project_name `ulp_pulse` to build the final output file.