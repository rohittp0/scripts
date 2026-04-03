#!/bin/bash

# Exit on errors
set -e

VOLUME="$1"
IMAGE="$2"

# Input validation
if [ -z $VOLUME ]; then
    echo "Usage: $0 <pg_volume> [<pg_image>]"
    exit 1
fi

if [ -z $IMAGE ]; then
 IMAGE="postgres:latest"
fi

docker run --rm -it \
  -v "${VOLUME}":/var/lib/postgresql/ \
  --user postgres \
  ${IMAGE} \
  pg_resetwal -f /var/lib/postgresql/

echo "PG WALL reset"
