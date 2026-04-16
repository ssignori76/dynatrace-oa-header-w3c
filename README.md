# Dynatrace OneAgent — W3C Trace Context Header Probe

Test project to verify which HTTP headers are injected by **Dynatrace OneAgent** when monitoring a Java application.

Headers under test:
- `traceparent` — W3C Trace Context standard
- `tracestate` — W3C Trace Context standard (optional)
- `x-dynatrace` — Dynatrace proprietary legacy header

---

## Architecture

```
┌─────────────────────────────────┐        HTTP        ┌──────────────────────────┐
│  caller (Spring Boot :8080)     │ ─────────────────► │  receiver (:9090)        │
│                                 │                    │                          │
│  GET /call                      │  traceparent: ...  │  prints all headers      │
│    └─► RestTemplate             │  x-dynatrace: ...  │  always returns 200 OK   │
│         └─► Apache HttpClient   │  x-probe-ts: ...   │                          │
│              ↑                  │                    └──────────────────────────┘
│     OneAgent injects here       │
└─────────────────────────────────┘
```

**Caller**: Spring Boot backed by Apache HttpClient 5. OneAgent instruments this client and injects trace headers before the TCP send. Wire-level logging is enabled so injected headers are also visible in the caller's stdout.

**Receiver**: minimal echo server written in plain Java (zero dependencies). Prints all incoming headers and always returns `200 OK`.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Java 17 | Not required on the host — `setup.sh` downloads it project-locally |
| Maven | Not required — Maven Wrapper (`mvnw`) is included |
| Dynatrace OneAgent | Must be installed on the **caller** machine |
| Internet access | Required on first run to download JDK and Maven |

Neither Java nor Maven need to be installed on the target machine. The project is fully self-contained.

---

## Setup (run once)

```bash
git clone https://github.com/ssignori76/dynatrace-oa-header-w3c.git
cd dynatrace-oa-header-w3c
./setup.sh
```

`setup.sh` downloads **Amazon Corretto 17** into `.jdk/` inside the project folder. It auto-detects the CPU architecture (`x86_64` / `aarch64`). The system Java is never touched.

---

## Build

```bash
./build.sh
```

Uses the project-local JDK and Maven Wrapper to produce `caller/target/caller-1.0.0.jar`.

---

## Run

Open three terminals on the target machine.

### Terminal 1 — Receiver

```bash
./run-receiver.sh
# or on a custom port:
./run-receiver.sh 9091
```

Expected output:
```
Starting receiver on port 9090...
Receiver in ascolto su porta 9090
Endpoint: http://0.0.0.0:9090/headers
```

### Terminal 2 — Caller (with OneAgent)

```bash
ONEAGENT_JAR=/path/to/oneagent.jar ./run-caller.sh
```

`TARGET_URL` defaults to `http://localhost:9090/headers` and can be overridden — see the [Configuring the Target Endpoint](#configuring-the-target-endpoint) section below.

### Terminal 3 — Send a test request

```bash
./test.sh
# or with a remote caller:
./test.sh caller-host 8080
```

---

## What to look for

### Receiver output

With OneAgent active and W3C Trace Context enabled, every request should show:

```
=== RICHIESTA RICEVUTA ===
Metodo : GET
URI    : /headers
Da     : 10.0.1.5:54321
--- Header ---
  traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
  tracestate: ...
  x-dynatrace: FW4;...
  x-probe-ts: 2024-01-15T10:30:00Z
==========================
```

### Caller output — two sections

1. **`>>> APP-LEVEL HEADERS`** — headers added by the application before OneAgent acts. `traceparent` / `x-dynatrace` will **not** appear here.

2. **Apache HttpClient wire log** — raw bytes sent over the wire, **after** OneAgent has injected its headers:
   ```
   >> "traceparent: 00-...-01[\r][\n]"
   >> "x-dynatrace: FW4;...[\r][\n]"
   ```

### Independent verification with tcpdump

```bash
sudo tcpdump -i any -A 'tcp port 9090' | grep -E 'traceparent|tracestate|x-dynatrace'
```

---

## Configuring the Target Endpoint

The URL that the caller sends requests to is controlled by the `TARGET_URL` environment variable. This makes it possible to test different scenarios without rebuilding anything.

### Phase 1 — Direct call (caller → receiver)

Default configuration. Receiver and caller on the same host or on two separate VMs.

```
[caller :8080] ──────────────────────────────► [receiver :9090]
                  traceparent injected by OneAgent
```

```bash
# same host (default)
ONEAGENT_JAR=/path/to/oneagent.jar \
./run-caller.sh

# receiver on a separate VM
ONEAGENT_JAR=/path/to/oneagent.jar \
TARGET_URL=http://receiver-host:9090/headers \
./run-caller.sh
```

---

### Phase 2 — API Gateway in the middle (caller → API GW → receiver)

Point `TARGET_URL` to the API Gateway endpoint. The receiver stays unchanged and keeps listening on `:9090` as the API GW backend.

```
[caller :8080] ──► [API Gateway] ──► [receiver :9090]
                        ↑
               does it forward / strip / modify
               traceparent and x-dynatrace ?
```

```bash
ONEAGENT_JAR=/path/to/oneagent.jar \
TARGET_URL=http://api-gateway-host/headers \
./run-caller.sh
```

**What to compare between Phase 1 and Phase 2:**

| Header | Phase 1 (direct) | Phase 2 (via API GW) | Expected behaviour |
|---|---|---|---|
| `traceparent` | present | ? | should be forwarded unchanged |
| `tracestate` | present | ? | should be forwarded unchanged |
| `x-dynatrace` | present | ? | depends on API GW configuration |
| `x-probe-ts` | present | ? | should be forwarded unchanged |

If a header is visible in Phase 1 but missing in Phase 2, the API Gateway is stripping it. If the value changes, the API GW is rewriting it.

**Tip — use tcpdump on the receiver host to get ground truth:**
```bash
sudo tcpdump -i any -A 'tcp port 9090' | grep -E 'traceparent|tracestate|x-dynatrace'
```

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| No `traceparent` in receiver | W3C Trace Context not enabled in the Dynatrace tenant |
| No `x-dynatrace` in receiver | Legacy header disabled or process not instrumented |
| No outbound span in Dynatrace | Apache HttpClient not instrumented by this OneAgent version |
| Headers in wire log but missing in receiver | Proxy or API GW between caller and receiver is stripping headers |

To confirm the Java process is seen by OneAgent: check **Dynatrace → Technologies → Java** and verify the process appears as a service.

---

## Project structure

```
.
├── setup.sh          # download Amazon Corretto 17 into .jdk/
├── build.sh          # build caller JAR using project-local JDK
├── run-receiver.sh   # start the echo receiver
├── run-caller.sh     # start the caller (set ONEAGENT_JAR and TARGET_URL)
├── test.sh           # send a test request via curl
├── caller/           # Spring Boot app (Apache HttpClient 5 + wire logging)
│   ├── mvnw
│   ├── pom.xml
│   └── src/
└── receiver/
    └── ReceiverApp.java   # single-file echo server, no dependencies
```
