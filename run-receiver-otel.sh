#!/bin/bash
# Starts the receiver with the OpenTelemetry Java agent.
# Prerequisite: ./setup.sh and ./setup-otel.sh
#
# Usage: ./run-receiver-otel.sh [port]   default: 9090
#
# Environment variables:
#   OTEL_AGENT_JAR  override the OTel agent path (default: .otel/opentelemetry-javaagent.jar)
#
# For Dynatrace OneAgent use run-receiver.sh instead.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JDK_DIR="${SCRIPT_DIR}/.jdk"
OTEL_JAR="${OTEL_AGENT_JAR:-${SCRIPT_DIR}/.otel/opentelemetry-javaagent.jar}"

if [ ! -d "${JDK_DIR}/bin" ]; then
    echo "JDK not found. Run ./setup.sh first."
    exit 1
fi

if [ ! -f "${OTEL_JAR}" ]; then
    echo "OTel agent not found at: ${OTEL_JAR}"
    echo "Run ./setup-otel.sh first."
    exit 1
fi

PORT="${1:-9090}"
echo "Mode       : OpenTelemetry"
echo "Agent JAR  : ${OTEL_JAR}"
echo "Starting receiver on port ${PORT}..."
"${JDK_DIR}/bin/java" \
    -javaagent:"${OTEL_JAR}" \
    "${SCRIPT_DIR}/receiver/ReceiverApp.java" "${PORT}"
