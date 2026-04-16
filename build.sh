#!/bin/bash
# Builds the caller JAR using the project-local JDK.
# Prerequisite: run ./setup.sh first.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JDK_DIR="${SCRIPT_DIR}/.jdk"

if [ ! -d "${JDK_DIR}/bin" ]; then
    echo "JDK not found. Run ./setup.sh first."
    exit 1
fi

export JAVA_HOME="${JDK_DIR}"
export PATH="${JAVA_HOME}/bin:${PATH}"

echo "Java : $(java -version 2>&1 | head -1)"
echo "Building caller..."

cd "${SCRIPT_DIR}/caller"
./mvnw package -q

echo "Build complete: caller/target/caller-1.0.0.jar"
