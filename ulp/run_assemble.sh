#!/bin/sh

docker run -it --rm --name ulp-assemble -v "$PWD":/code -w /code mpte micropython assemble.py ulp_pulse
