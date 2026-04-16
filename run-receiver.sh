#!/bin/bash
# Starts the echo receiver using the project-local JDK.
# Usage: ./run-receiver.sh [port]   default port: 9090
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JDK_DIR="${SCRIPT_DIR}/.jdk"

if [ ! -d "${JDK_DIR}/bin" ]; then
    echo "JDK not found. Run ./setup.sh first."
    exit 1
fi

PORT="${1:-9090}"
echo "Starting receiver on port ${PORT}..."
"${JDK_DIR}/bin/java" "${SCRIPT_DIR}/receiver/ReceiverApp.java" "${PORT}"
