#!/bin/bash
# Starts the caller with the OpenTelemetry Java agent.
# Prerequisite: ./setup.sh, ./setup-otel.sh and ./build.sh
#
# Environment variables:
#   TARGET_URL      URL the caller will send requests to (default: http://localhost:9090/headers)
#   OTEL_AGENT_JAR  override the OTel agent path (default: .otel/opentelemetry-javaagent.jar)
#
# For Dynatrace OneAgent use run-caller.sh instead.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JDK_DIR="${SCRIPT_DIR}/.jdk"
JAR="${SCRIPT_DIR}/caller/target/caller-1.0.0.jar"
OTEL_JAR="${OTEL_AGENT_JAR:-${SCRIPT_DIR}/.otel/opentelemetry-javaagent.jar}"

if [ ! -d "${JDK_DIR}/bin" ]; then
    echo "JDK not found. Run ./setup.sh first."
    exit 1
fi

if [ ! -f "${JAR}" ]; then
    echo "JAR not found. Run ./build.sh first."
    exit 1
fi

if [ ! -f "${OTEL_JAR}" ]; then
    echo "OTel agent not found at: ${OTEL_JAR}"
    echo "Run ./setup-otel.sh first."
    exit 1
fi

export JAVA_HOME="${JDK_DIR}"
export TARGET_URL="${TARGET_URL:-http://localhost:9090/headers}"

echo "Mode       : OpenTelemetry"
echo "Agent JAR  : ${OTEL_JAR}"
echo "Target URL : ${TARGET_URL}"
echo "Starting caller on port 8080..."

"${JAVA_HOME}/bin/java" \
    -javaagent:"${OTEL_JAR}" \
    -jar "${JAR}"
