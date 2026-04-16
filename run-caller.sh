#!/bin/bash
# Starts the caller without any explicit agent.
# Dynatrace OneAgent (system-installed) will instrument automatically.
# Prerequisite: ./setup.sh and ./build.sh
#
# Environment variables:
#   TARGET_URL   URL the caller will send requests to (default: http://localhost:9090/headers)
#
# For OpenTelemetry use run-caller-otel.sh instead.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JDK_DIR="${SCRIPT_DIR}/.jdk"
JAR="${SCRIPT_DIR}/caller/target/caller-1.0.0.jar"

if [ ! -d "${JDK_DIR}/bin" ]; then
    echo "JDK not found. Run ./setup.sh first."
    exit 1
fi

if [ ! -f "${JAR}" ]; then
    echo "JAR not found. Run ./build.sh first."
    exit 1
fi

export JAVA_HOME="${JDK_DIR}"
export TARGET_URL="${TARGET_URL:-http://localhost:9090/headers}"

echo "Mode       : Dynatrace OneAgent (system-installed)"
echo "Target URL : ${TARGET_URL}"
echo "Starting caller on port 8080..."

"${JAVA_HOME}/bin/java" -jar "${JAR}"
