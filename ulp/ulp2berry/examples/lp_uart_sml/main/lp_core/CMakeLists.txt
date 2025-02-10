cmake_minimum_required(VERSION 3.16)

# Project/target name is passed from the main project
project(${ULP_APP_NAME})

# Import the ULP project helper functions
include(IDFULPProject)

# Create executable
add_executable(${ULP_APP_NAME} main.c)

# Apply default compile options
ulp_apply_default_options(${ULP_APP_NAME})

# Apply default sources provided by the IDF ULP component
ulp_apply_default_sources(${ULP_APP_NAME})

# Add targets for building the binary
ulp_add_build_binary_targets(${ULP_APP_NAME})

# Set custom compile flags
target_compile_options(${ULP_APP_NAME} PRIVATE -msave-restore)
