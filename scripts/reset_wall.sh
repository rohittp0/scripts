#!/bin/bash

# Exit on errors
set -e

VOLUME="$1"
VERSION="$2"

# Input validation
if [ -z $VOLUME ]; then
    echo "Usage: $0 <pg_volume> [<pg_version>]"
    exit 1
fi

if [ -z $VERSION ]; then
  $VERSION="latest"
fi

docker run --rm -it \
  -v "${VOLUME}":/var/lib/postgresql/data \
  --user postgres \
  postgis/postgis:${VERSION} \
  pg_resetwal -f /var/lib/postgresql/data

echo "PG WALL reset"
