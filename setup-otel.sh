#!/bin/bash
# Downloads the OpenTelemetry Java agent into .otel/ (project-local).
# Run once before using run-caller-otel.sh or run-receiver-otel.sh.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OTEL_DIR="${SCRIPT_DIR}/.otel"
OTEL_JAR="${OTEL_DIR}/opentelemetry-javaagent.jar"

if [ -f "${OTEL_JAR}" ]; then
    echo "OTel agent already present in .otel/ — skipping download."
    ls -lh "${OTEL_JAR}"
    exit 0
fi

mkdir -p "${OTEL_DIR}"
echo "Downloading OpenTelemetry Java agent (latest release)..."
curl -fSL \
    "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar" \
    -o "${OTEL_JAR}"

echo "Done."
ls -lh "${OTEL_JAR}"
