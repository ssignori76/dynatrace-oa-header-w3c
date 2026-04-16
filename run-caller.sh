#!/bin/bash
# Starts the caller using the project-local JDK.
# Prerequisite: run ./setup.sh and ./build.sh first.
#
# Environment variables:
#   TARGET_URL      URL the caller will send requests to (default: http://localhost:9090/headers)
#   OTEL_AGENT_JAR  path to the OpenTelemetry Java agent JAR (optional)
#                   Only needed for OpenTelemetry. Dynatrace OneAgent instruments
#                   automatically when installed at host level — no parameter required.
#
# Examples:
#   # Dynatrace OneAgent (system-installed, no extra params needed)
#   ./run-caller.sh
#
#   # OpenTelemetry Java agent
#   OTEL_AGENT_JAR=/path/to/opentelemetry-javaagent.jar ./run-caller.sh
#
#   # Custom target URL (e.g. API Gateway)
#   TARGET_URL=http://api-gateway-host/headers ./run-caller.sh

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
if [ -n "${OTEL_AGENT_JAR:-}" ]; then
    echo "Mode       : OpenTelemetry (javaagent)"
    echo "Agent JAR  : ${OTEL_AGENT_JAR}"
    JAVAAGENT_ARG="-javaagent:${OTEL_AGENT_JAR}"
else
    echo "Mode       : Dynatrace OneAgent (system-installed, no javaagent param)"
fi

echo "Target URL : ${TARGET_URL}"
echo "Starting caller on port 8080..."

"${JAVA_HOME}/bin/java" \
    ${JAVAAGENT_ARG} \
    -jar "${JAR}"
