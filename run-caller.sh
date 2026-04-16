#!/bin/bash
# Starts the caller using the project-local JDK.
# Prerequisite: run ./setup.sh and ./build.sh first.
#
# Environment variables:
#   ONEAGENT_JAR   path to the OneAgent JAR (required to observe trace headers)
#   TARGET_URL     URL the caller will call (default: http://localhost:9090/headers)
#
# Example:
#   ONEAGENT_JAR=/opt/dynatrace/oneagent/agent/lib64/liboneagentjava.jar \
#   TARGET_URL=http://receiver-host:9090/headers \
#   ./run-caller.sh
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

JAVAAGENT_ARG=""
if [ -n "${ONEAGENT_JAR:-}" ]; then
    echo "OneAgent : ${ONEAGENT_JAR}"
    JAVAAGENT_ARG="-javaagent:${ONEAGENT_JAR}"
else
    echo "WARNING: ONEAGENT_JAR not set — running without OneAgent (no trace headers expected)"
fi

echo "Target URL: ${TARGET_URL}"
echo "Starting caller on port 8080..."

"${JAVA_HOME}/bin/java" \
    ${JAVAAGENT_ARG} \
    -jar "${JAR}"
