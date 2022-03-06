#!/bin/bash

set -e

cd "$(git rev-parse --show-toplevel)"

FINGERPRINT="C16F4A099BEFD6EE6AA65C22ED7356C091A0A7DA"
COMMAND="$1"
FILE="$2"


if [ "$COMMAND" == "--export" ] && [ -n "$FILE" ]; then
  gpg --export-secret-keys $FINGERPRINT > $FILE
elif [ "$COMMAND" == "--import" ] && [ -n "$FILE" ]; then
  gpg --import $FILE
else
  cat << EOF
Usage:
  ./gpg.sh --export <FILENAME>
  ./gpg.sh --import <FILENAME>
EOF
fi

echo $USAGE
