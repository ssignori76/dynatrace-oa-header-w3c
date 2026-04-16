# W3C Trace Context Header Propagation Probe

Test project to verify that **W3C Trace Context headers** are correctly propagated when a Java application is monitored by either **Dynatrace OneAgent** or an **OpenTelemetry Java agent**.

The W3C Trace Context standard defines two headers:
- `traceparent` — carries the trace ID, span ID and sampling flags
- `tracestate` — carries vendor-specific trace state (optional)

Dynatrace OneAgent also injects its own legacy header:
- `x-dynatrace` — proprietary Dynatrace header (present alongside W3C headers when the feature is enabled)

Both agents implement the same W3C standard, so the test methodology is identical for both. The only difference is how the agent is activated — see [Running the services](#running-the-services).

---

## Architecture

```
┌─────────────────────────────────┐        HTTP        ┌──────────────────────────┐
│  caller (Spring Boot :8080)     │ ─────────────────► │  receiver (:9090)        │
│                                 │                    │                          │
│  GET /call                      │  traceparent: ...  │  prints all headers      │
│    └─► RestTemplate             │  tracestate:  ...  │  always returns 200 OK   │
│         └─► Apache HttpClient   │  x-dynatrace: ...  │                          │
│              ↑                  │                    └──────────────────────────┘
│      agent injects here         │
└─────────────────────────────────┘
```

**Caller**: Spring Boot backed by Apache HttpClient 5. The agent instruments this client and injects trace headers before the TCP send. Wire-level logging is enabled so injected headers are also visible in the caller's stdout.

**Receiver**: minimal echo server in plain Java (zero dependencies). Prints all incoming headers and always returns `200 OK`.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Java 17 | Not required on the host — `setup.sh` downloads it project-locally |
| Maven | Not required — Maven Wrapper (`mvnw`) is included |
| Dynatrace OneAgent **or** OTel agent | Must be active on the caller machine |
| Internet access | Required on first run to download JDK, Maven and OTel agent |

Neither Java nor Maven need to be installed on the target machine. The project is fully self-contained.

---

## Setup

### Step 1 — Clone and build

```bash
git clone https://github.com/ssignori76/dynatrace-oa-header-w3c.git
cd dynatrace-oa-header-w3c

./setup.sh    # downloads Amazon Corretto 17 into .jdk/  (~200 MB, once)
./build.sh    # compiles the caller JAR
```

### Step 2 — Download the OTel agent (only for the OpenTelemetry scenario)

```bash
./setup-otel.sh   # downloads opentelemetry-javaagent.jar into .otel/  (~23 MB, once)
```

The agent is stored at `.otel/opentelemetry-javaagent.jar` and is picked up automatically by `run-caller-otel.sh` and `run-receiver-otel.sh`.

---

## Running the services

Each service has two start scripts — one per agent mode. Pick the pair that matches your scenario.

### Dynatrace OneAgent

OneAgent is installed at the **host level** and instruments all Java processes automatically. No `-javaagent` parameter is needed.

```bash
# terminal 1
./run-receiver.sh

# terminal 2
./run-caller.sh
```

### OpenTelemetry

The OTel agent is passed explicitly as `-javaagent`. Run `./setup-otel.sh` first.

> **Note**: the OTel agent adds ~10 seconds to startup time on first launch.

```bash
# terminal 1
./run-receiver-otel.sh

# terminal 2
./run-caller-otel.sh
```

Both scripts look for the agent at `.otel/opentelemetry-javaagent.jar` by default. To use a different path:

```bash
OTEL_AGENT_JAR=/path/to/opentelemetry-javaagent.jar ./run-caller-otel.sh
```

---

## Send a test request

```bash
# terminal 3
./test.sh

# or with a remote caller:
./test.sh caller-host 8080
```

---

## What to look for

### Receiver output

With the agent active, every request should include the `traceparent` header:

```
=== RICHIESTA RICEVUTA ===
Metodo : GET
URI    : /headers
Da     : 10.0.1.5:54321
--- Header ---
  Traceparent: 00-a09ac30851b450c7b544fc77fcabe48c-5a6c2cc09fee4807-01
  Tracestate: ...
  X-dynatrace: FW4;...          ← Dynatrace only
  X-probe-ts: 2026-04-16T13:01:53Z
==========================
```

### Caller output — two sections

1. **`>>> APP-LEVEL HEADERS`** — headers added by the application before the agent acts. `traceparent` will **not** appear here.

2. **Apache HttpClient wire log** — raw bytes sent over the wire, **after** the agent has injected its headers:
   ```
   >> "traceparent: 00-a09ac30851b450c7b544fc77fcabe48c-5a6c2cc09fee4807-01[\r][\n]"
   >> "x-dynatrace: FW4;...[\r][\n]"   ← Dynatrace only
   ```

### Expected headers by agent

| Header | Dynatrace OneAgent | OpenTelemetry |
|---|---|---|
| `traceparent` | yes | yes |
| `tracestate` | yes | yes |
| `x-dynatrace` | yes (legacy) | no |

### Independent verification with tcpdump

```bash
sudo tcpdump -i any -A 'tcp port 9090' | grep -E 'traceparent|tracestate|x-dynatrace'
```

---

## Configuring the Target Endpoint

The URL the caller sends requests to is controlled by `TARGET_URL`. Change it at runtime without rebuilding.

### Phase 1 — Direct call (caller → receiver)

Default configuration.

```
[caller :8080] ──────────────────────────────► [receiver :9090]
                  traceparent injected by agent
```

```bash
# same host (default)
./run-caller.sh

# receiver on a separate VM
TARGET_URL=http://receiver-host:9090/headers ./run-caller.sh
```

### Phase 2 — API Gateway in the middle

Point `TARGET_URL` to the API Gateway. The receiver keeps listening on `:9090` as the backend.

```
[caller :8080] ──► [API Gateway] ──► [receiver :9090]
                        ↑
               does it forward / strip / modify
               traceparent and x-dynatrace ?
```

```bash
TARGET_URL=http://api-gateway-host/headers ./run-caller.sh
# or with OTel:
TARGET_URL=http://api-gateway-host/headers ./run-caller-otel.sh
```

**What to compare between Phase 1 and Phase 2:**

| Header | Phase 1 (direct) | Phase 2 (via API GW) | Expected |
|---|---|---|---|
| `traceparent` | present | ? | forwarded unchanged |
| `tracestate` | present | ? | forwarded unchanged |
| `x-dynatrace` | present | ? | depends on API GW config |
| `x-probe-ts` | present | ? | forwarded unchanged |

If a header visible in Phase 1 is missing in Phase 2, the API GW is stripping it. If the value changes, it is rewriting it.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| No `traceparent` in receiver | W3C propagation not enabled, or agent not active |
| No `x-dynatrace` in receiver | Legacy header disabled or process not instrumented (Dynatrace only) |
| No outbound span in Dynatrace | Apache HttpClient not instrumented by this OneAgent version |
| Headers in wire log but missing in receiver | API GW or proxy is stripping headers |
| `JAVA_HOME not defined` on `./mvnw` | Run `./setup.sh` first |
| Caller with OTel not ready after 5s | OTel agent needs ~10s on first start — wait and retry `./test.sh` |

To confirm the Java process is seen by Dynatrace OneAgent: **Dynatrace → Technologies → Java** — the process should appear as a service.

---

## Project structure

```
.
├── setup.sh               # download Amazon Corretto 17 into .jdk/
├── setup-otel.sh          # download OTel Java agent into .otel/
├── build.sh               # compile the caller JAR
│
├── run-receiver.sh        # start receiver  — Dynatrace OneAgent mode
├── run-receiver-otel.sh   # start receiver  — OpenTelemetry mode
├── run-caller.sh          # start caller    — Dynatrace OneAgent mode
├── run-caller-otel.sh     # start caller    — OpenTelemetry mode
│
├── test.sh                # send a test request via curl
│
├── caller/                # Spring Boot app (Apache HttpClient 5 + wire logging)
│   ├── mvnw               # Maven Wrapper — auto-detects .jdk/ for JAVA_HOME
│   ├── pom.xml
│   └── src/
└── receiver/
    └── ReceiverApp.java   # single-file echo server, no dependencies
```
