#!/bin/bash
# Test W3C header propagation via Dynatrace OneAgent
# Uso: ./test.sh [caller_host] [caller_port]

CALLER_HOST=${1:-localhost}
CALLER_PORT=${2:-8080}
URL="http://${CALLER_HOST}:${CALLER_PORT}/call"

echo "======================================="
echo "  Dynatrace W3C Header Probe"
echo "======================================="
echo "Caller: ${URL}"
echo ""
echo ">>> Invio richiesta..."
echo ""
curl -s -w "\nHTTP status: %{http_code}\n" "${URL}"
echo ""
echo "======================================="
echo "Controlla l'output del receiver per vedere"
echo "gli header iniettati da OneAgent:"
echo "  traceparent: 00-<traceid>-<spanid>-<flags>"
echo "  tracestate:  ..."
echo "  x-dynatrace: ..."
echo "======================================="
