#!/bin/sh

# Iterate over all files in the current directory
for f in *; do
    # Check if the file is a directory and not the dist directory
    if [ -d "$f" ] && [ "$f" != "dist" ]; then
        # Will not run if no directories are available
        echo "Packing $f"
        # Create a zip pack file (no compression) with the name of the directory with the ".autoconf" extension
        zip -0 -j dist/$f.autoconf $f/*
    fi
done