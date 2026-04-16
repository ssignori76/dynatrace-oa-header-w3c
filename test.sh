#!/bin/bash
# Sends a test request to the caller and shows the response.
# The receiver log will show the headers injected by OneAgent.
# Usage: ./test.sh [caller_host] [caller_port]

CALLER_HOST="${1:-localhost}"
CALLER_PORT="${2:-8080}"
URL="http://${CALLER_HOST}:${CALLER_PORT}/call"

echo "======================================="
echo "  Dynatrace W3C Header Probe — Test"
echo "======================================="
echo "Caller : ${URL}"
echo ""
echo "Sending request..."
echo ""
curl -s -w "\nHTTP status: %{http_code}\n" "${URL}"
echo ""
echo "======================================="
echo "Check the receiver output for headers"
echo "injected by OneAgent:"
echo "  traceparent: 00-<traceid>-<spanid>-<flags>"
echo "  tracestate:  ..."
echo "  x-dynatrace: ..."
echo "======================================="
