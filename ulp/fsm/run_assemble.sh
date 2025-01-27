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
