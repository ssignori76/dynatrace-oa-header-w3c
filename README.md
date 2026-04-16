# Dynatrace OneAgent — W3C Trace Context Header Probe

Progetto di test per verificare quali header HTTP vengono iniettati da **Dynatrace OneAgent** quando monitora un'applicazione Java.

Verifica in particolare la propagazione degli header:
- `traceparent` — W3C Trace Context standard
- `tracestate` — W3C Trace Context standard (opzionale)
- `x-dynatrace` — header proprietario Dynatrace (legacy)

---

## Architettura

```
┌─────────────────────────────────┐        HTTP        ┌──────────────────────────┐
│  caller (Spring Boot :8080)     │ ─────────────────► │  receiver (:9090)        │
│                                 │                    │                          │
│  GET /call                      │  traceparent: ...  │  stampa tutti gli header │
│    └─► RestTemplate             │  x-dynatrace: ...  │  risponde 200 OK         │
│         └─► Apache HttpClient   │  x-probe-ts: ...   │                          │
│              ↑                  │                    └──────────────────────────┘
│         OneAgent inietta qui    │
└─────────────────────────────────┘
```

**Caller**: Spring Boot con Apache HttpClient 5. OneAgent strumenta questo client e inietta gli header di trace prima dell'invio TCP.

**Receiver**: echo server minimale scritto in Java puro (nessuna dipendenza). Stampa tutti gli header ricevuti e risponde sempre `200 OK`.

---

## Prerequisiti

- Java 17+
- Maven **non necessario** — il progetto include il Maven Wrapper (`mvnw`)
- Dynatrace OneAgent installato sulla macchina del caller

---

## Build

Il progetto usa il **Maven Wrapper**: scarica automaticamente la versione corretta di Maven al primo build, senza richiedere Maven installato sul sistema.

La cache viene scaricata in `caller/.maven/` (cartella del progetto, non nella home utente) e non viene committata nel repo.

```bash
cd caller
./mvnw package -q
```

Produce: `caller/target/caller-1.0.0.jar`

> **Nota**: al primo `./mvnw` viene scaricato Maven (~10 MB). Richiede connettività internet verso `repo.maven.apache.org`.

---

## Avvio

### Terminal 1 — Receiver

```bash
cd receiver
java ReceiverApp.java
# oppure su porta diversa:
java ReceiverApp.java 9091
```

Output atteso:
```
Receiver in ascolto su porta 9090
Endpoint: http://0.0.0.0:9090/headers
```

### Terminal 2 — Caller (con OneAgent)

```bash
cd caller
java -javaagent:/path/to/oneagent.jar \
     -jar target/caller-1.0.0.jar
```

La URL target è configurabile tramite variabile d'ambiente (utile nella fase 2 con API Gateway):

```bash
TARGET_URL=http://receiver-host:9090/headers \
java -javaagent:/path/to/oneagent.jar \
     -jar target/caller-1.0.0.jar
```

Default: `http://localhost:9090/headers`

### Terminal 3 — Esegui il test

```bash
./test.sh
# oppure con host remoto:
./test.sh caller-host 8080
```

---

## Cosa osservare

### Log del receiver

Il receiver stampa tutti gli header ricevuti. Con OneAgent attivo e W3C Trace Context abilitato, dovrai vedere:

```
=== RICHIESTA RICEVUTA ===
Metodo : GET
URI    : /headers
Da     : 192.168.1.10:54321
--- Header ---
  traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
  tracestate: ...
  x-dynatrace: FW4;...
  x-probe-ts: 2024-01-15T10:30:00Z
==========================
```

### Log del caller (wire log)

Il caller stampa due sezioni:

1. **`>>> APP-LEVEL HEADERS`** — header aggiunti dall'applicazione (senza OneAgent). Qui **non** si vedranno `traceparent` / `x-dynatrace`.

2. **Wire log Apache HttpClient** — byte raw inviati sulla rete, **dopo** che OneAgent ha iniettato gli header:
   ```
   >> "traceparent: 00-...-01[\r][\n]"
   >> "x-dynatrace: FW4;...[\r][\n]"
   ```

### tcpdump (verifica indipendente)

```bash
sudo tcpdump -i any -A 'tcp port 9090' | grep -E 'traceparent|tracestate|x-dynatrace'
```

---

## Troubleshooting

| Sintomo | Causa probabile |
|---|---|
| Nessun `traceparent` nel receiver | W3C Trace Context non abilitato nel tenant Dynatrace |
| Nessun `x-dynatrace` nel receiver | Header legacy disabilitato oppure il processo non è instrumentato |
| Nessuno span outbound in Dynatrace | Apache HttpClient non strumentato nella versione OneAgent in uso |
| Header presenti nel wire log ma non nel receiver | Proxy/LB intermedio che riscrive gli header |

Per verificare che il processo Java sia visto da OneAgent: controlla in Dynatrace → **Technologies** → **Java** che il processo appaia come servizio.

---

## Fase 2 — Test con API Gateway

Per inserire un API Gateway tra caller e receiver, basta cambiare `TARGET_URL`:

```bash
TARGET_URL=http://api-gateway-host/headers \
java -javaagent:/path/to/oneagent.jar \
     -jar target/caller-1.0.0.jar
```

Il receiver continua ad ascoltare su `:9090` come backend dell'API GW. Questo permette di osservare se il gateway propaga, modifica o rimuove gli header iniettati da OneAgent.
