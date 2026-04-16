# W3C Trace Context Header Propagation Probe

Test project to verify that **W3C Trace Context headers** are correctly propagated when a Java application is monitored by either **Dynatrace OneAgent** or an **OpenTelemetry Java agent**.

The W3C Trace Context standard defines two headers:
- `traceparent` — carries the trace ID, span ID and sampling flags
- `tracestate` — carries vendor-specific trace state (optional)

Dynatrace OneAgent also injects its own legacy header:
- `x-dynatrace` — proprietary Dynatrace header (present alongside W3C headers when the feature is enabled)

Both OneAgent and OpenTelemetry implement the same W3C standard, so the test methodology is identical for both. The only difference is how the agent is activated — see [Running the Caller](#running-the-caller).

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
  OneAgent: installed at host level, no config needed
  OpenTelemetry: pass -javaagent:opentelemetry-javaagent.jar
```

**Caller**: Spring Boot backed by Apache HttpClient 5. The agent instruments this client and injects trace headers before the TCP send. Wire-level logging is enabled so injected headers are visible in the caller's stdout as well.

**Receiver**: minimal echo server written in plain Java (zero dependencies). Prints all incoming headers and always returns `200 OK`.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Java 17 | Not required on the host — `setup.sh` downloads it project-locally |
| Maven | Not required — Maven Wrapper (`mvnw`) is included |
| Dynatrace OneAgent **or** OTel agent | Must be active on the **caller** machine |
| Internet access | Required on first run to download JDK and Maven |

Neither Java nor Maven need to be installed on the target machine. The project is fully self-contained.

---

## Quick start

```bash
git clone https://github.com/ssignori76/dynatrace-oa-header-w3c.git
cd dynatrace-oa-header-w3c

./setup.sh    # download Amazon Corretto 17 into .jdk/ (once)
./build.sh    # compile the caller JAR
```

Then open three terminals:

```bash
# terminal 1
./run-receiver.sh

# terminal 2 — pick one:
./run-caller.sh                                              # Dynatrace OneAgent
OTEL_AGENT_JAR=/path/to/opentelemetry-javaagent.jar \
./run-caller.sh                                              # OpenTelemetry

# terminal 3
./test.sh
```

---

## Setup

`setup.sh` downloads **Amazon Corretto 17** into `.jdk/` inside the project folder. It auto-detects the CPU architecture (`x86_64` / `aarch64`). The system Java is never touched.

```bash
./setup.sh
```

---

## Build

```bash
./build.sh
```

Uses the project-local JDK and Maven Wrapper to produce `caller/target/caller-1.0.0.jar`.

`./mvnw` also works directly — it auto-detects `.jdk/` and sets `JAVA_HOME` before building.

---

## Running the Caller

`TARGET_URL` defaults to `http://localhost:9090/headers` and can be overridden at any time without rebuilding — see [Configuring the Target Endpoint](#configuring-the-target-endpoint).

### Dynatrace OneAgent

OneAgent is installed at the **host level** and instruments all Java processes automatically. No `-javaagent` parameter is needed — just start the caller normally:

```bash
./run-caller.sh
```

### OpenTelemetry Java agent

The OTel agent must be passed explicitly via `OTEL_AGENT_JAR`:

```bash
OTEL_AGENT_JAR=/path/to/opentelemetry-javaagent.jar ./run-caller.sh
```

---

## What to look for

### Receiver output

With the agent active and W3C Trace Context propagation enabled, every request should show:

```
=== RICHIESTA RICEVUTA ===
Metodo : GET
URI    : /headers
Da     : 10.0.1.5:54321
--- Header ---
  traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
  tracestate: ...
  x-dynatrace: FW4;...          ← Dynatrace only
  x-probe-ts: 2024-01-15T10:30:00Z
==========================
```

### Caller output — two sections

1. **`>>> APP-LEVEL HEADERS`** — headers added by the application before the agent acts. `traceparent` / `x-dynatrace` will **not** appear here.

2. **Apache HttpClient wire log** — raw bytes sent over the wire, **after** the agent has injected its headers:
   ```
   >> "traceparent: 00-...-01[\r][\n]"
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

The URL that the caller sends requests to is controlled by the `TARGET_URL` environment variable. This makes it possible to test different scenarios without rebuilding anything.

### Phase 1 — Direct call (caller → receiver)

Default configuration. Receiver and caller on the same host or on two separate VMs.

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

### Phase 2 — API Gateway in the middle (caller → API GW → receiver)

Point `TARGET_URL` to the API Gateway endpoint. The receiver stays unchanged and keeps listening on `:9090` as the API GW backend.

```
[caller :8080] ──► [API Gateway] ──► [receiver :9090]
                        ↑
               does it forward / strip / modify
               traceparent and x-dynatrace ?
```

```bash
TARGET_URL=http://api-gateway-host/headers ./run-caller.sh
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
| No `traceparent` in receiver | W3C Trace Context propagation not enabled |
| No `x-dynatrace` in receiver | Legacy header disabled or process not instrumented (Dynatrace only) |
| No outbound span in Dynatrace | Apache HttpClient not instrumented by this OneAgent version |
| Headers in wire log but missing in receiver | API GW or proxy between caller and receiver is stripping headers |
| `JAVA_HOME not defined` on `./mvnw` | Run `./setup.sh` first to create the project-local `.jdk/` |

To confirm the Java process is seen by Dynatrace OneAgent: check **Dynatrace → Technologies → Java** and verify the process appears as a service.

---

## Project structure

```
.
├── setup.sh          # download Amazon Corretto 17 into .jdk/
├── build.sh          # build caller JAR using project-local JDK
├── run-receiver.sh   # start the echo receiver
├── run-caller.sh     # start the caller (set OTEL_AGENT_JAR and/or TARGET_URL)
├── test.sh           # send a test request via curl
├── caller/           # Spring Boot app (Apache HttpClient 5 + wire logging)
│   ├── mvnw          # Maven Wrapper — auto-detects .jdk/ for JAVA_HOME
│   ├── pom.xml
│   └── src/
└── receiver/
    └── ReceiverApp.java   # single-file echo server, no dependencies
```
