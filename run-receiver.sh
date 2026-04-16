#!/bin/bash
# Starts the receiver without any explicit agent.
# Dynatrace OneAgent (system-installed) will instrument automatically.
# Prerequisite: ./setup.sh
#
# Usage: ./run-receiver.sh [port]   default: 9090
#
# For OpenTelemetry use run-receiver-otel.sh instead.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JDK_DIR="${SCRIPT_DIR}/.jdk"

if [ ! -d "${JDK_DIR}/bin" ]; then
    echo "JDK not found. Run ./setup.sh first."
    exit 1
fi

PORT="${1:-9090}"
echo "Mode       : Dynatrace OneAgent (system-installed)"
echo "Starting receiver on port ${PORT}..."
"${JDK_DIR}/bin/java" "${SCRIPT_DIR}/receiver/ReceiverApp.java" "${PORT}"
