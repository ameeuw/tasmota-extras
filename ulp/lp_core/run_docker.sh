#!/bin/sh

# Default project directory is current directory
PROJECT_DIR=$PWD

# Parse command line arguments
while getopts ":hp:" opt; do
  case $opt in
    h)
      echo "Usage: $0 [-h] [-p project_dir]"
      echo "Options:"
      echo "  -h            Show this help message"
      echo "  -p directory  Set project directory (default: current directory)"
      exit 0
      ;;
    p)
      # Convert to absolute path
      PROJECT_DIR=$(cd "$OPTARG" 2>/dev/null && pwd || echo "$OPTARG")
      if [ ! -d "$PROJECT_DIR" ]; then
        echo "Error: Directory '$OPTARG' does not exist or is not accessible" >&2
        exit 1
      fi
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

echo "Project directory: $PROJECT_DIR"
docker run -it --rm \
-v $PROJECT_DIR:/project \
-w /project \
-u $UID \
-e HOME=/tmp \
esp-idf-berry