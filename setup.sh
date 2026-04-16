#!/bin/bash
# Downloads Amazon Corretto 17 into .jdk/ (project-local, does not touch system Java).
# Run once before build.sh.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JDK_DIR="${SCRIPT_DIR}/.jdk"

if [ -d "${JDK_DIR}/bin" ]; then
    echo "JDK already present in .jdk/ — skipping download."
    echo "Java: $("${JDK_DIR}/bin/java" -version 2>&1 | head -1)"
    exit 0
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  CORRETTO_ARCH="x64" ;;
    aarch64) CORRETTO_ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

URL="https://corretto.aws/downloads/latest/amazon-corretto-17-${CORRETTO_ARCH}-linux-jdk.tar.gz"
TMP="/tmp/corretto-17.tar.gz"

echo "Downloading Amazon Corretto 17 (${ARCH}) from corretto.aws..."
curl -fSL "$URL" -o "$TMP"

echo "Extracting to .jdk/..."
mkdir -p "${JDK_DIR}"
tar -xzf "$TMP" -C "${JDK_DIR}" --strip-components=1
rm -f "$TMP"

echo "Done. Java: $("${JDK_DIR}/bin/java" -version 2>&1 | head -1)"
