#!/bin/sh

# Default project directory is current directory
PROJECT_DIR=$PWD
NAME=""

# Parse command line arguments
while getopts ":hp:n:" opt; do
  case $opt in
    h)
      echo "Usage: $0 [-h] [-p project_dir] [-n name]"
      echo "Options:"
      echo "  -h            Show this help message"
      echo "  -p directory  Set project directory (default: current directory)"
      echo "  -n name       Set container name (default: top directory name)"
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
    n)
      NAME="$OPTARG"
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

# If name is not set, use the top directory name from PROJECT_DIR
if [ -z "$NAME" ]; then
  NAME=$(basename "$PROJECT_DIR")
fi

echo "Project directory: $PROJECT_DIR"
echo "Container name: $NAME"
docker run -it --rm \
-v $PROJECT_DIR:/project \
-w /project \
-u $UID \
-e HOME=/tmp \
-e PROJECT_NAME=$NAME \
esp-idf-berry