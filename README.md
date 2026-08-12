# CRM — Portable Kanban CRM

[![Go Version](https://img.shields.io/badge/Go-1.22-00ADD8?style=flat&logo=go&logoColor=white)](https://go.dev/)
[![Elixir](https://img.shields.io/badge/Elixir-1.20-4B275F?style=flat&logo=elixir&logoColor=white)](https://elixir-lang.org/)
[![Rust](https://img.shields.io/badge/Rust-NIF-DEA584?style=flat&logo=rust&logoColor=white)](https://rust-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-LiveView-FF6A00?style=flat&logo=phoenixframework&logoColor=white)](https://phoenixframework.org/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat)](./LICENSE)
[![Platforms](https://img.shields.io/badge/Platforms-5-blue?style=flat)]()

> **Hybrid CRM core: Go + Elixir/Phoenix + Rust NIF.**
> 5 operating systems. 4 languages. 1 binary. No CGO. No cloud dependencies.

---

## Quick Start

### Method 1: Download Binary (Windows)

Download `crm-server.exe` from [GitHub Releases](https://github.com/Leonov792/crm/releases) and run:

```bash
crm-server.exe
# Open http://localhost:8080
```

### Method 2: Docker

```bash
git clone https://github.com/Leonov792/crm.git
cd crm
docker-compose up --build
# Go CRM:     http://localhost:8080
# LiveView:   http://localhost:4000
```

### Method 3: Build from Source

```bash
git clone https://github.com/Leonov792/crm.git
cd crm

# Build frontend
cd frontend && npm install && npm run build && cd ..

# Build + run Go server
go run .
# Open http://localhost:8080

# (Optional) Start LiveView dashboard
cd dashboard && mix deps.get && mix phx.server
# Open http://localhost:4000
```

### Prerequisites

| Component | Required For | Install |
|-----------|-------------|---------|
| **Go 1.22+** | Backend | [go.dev/dl](https://go.dev/dl/) |
| **Node.js 20+** | Frontend | [nodejs.org](https://nodejs.org/) |
| **Elixir 1.17+** | Dashboard | `winget install Elixir.Elixir` |
| **Erlang/OTP 27+** | Dashboard | `winget install Erlang.Erlang` |
| **Rust** | NIF (optional) | [rustup.rs](https://rustup.rs/) |

---

## Architecture

```
 Browser                 Browser              Android APK
    │                       │                     │
    │ HTTP :8080            │ WebSocket :4000     │ Capacitor
    ▼                       ▼                     ▼
┌──────────┐         ┌──────────────┐      ┌──────────┐
│  Go CRM  │◄─HTTP──►│  Elixir/Phoenix│     │  Mobile  │
│  :8080   │  poll   │  :4000        │     │  WebView │
│          │  5 sec  │               │     └──────────┘
│ SQLite   │         │ LiveView      │
│ REST API │         │ GenStage      │
│ embedded │         │ PubSub        │
│ React SPA│         │      │        │
└──────────┘         │ Rustler NIF   │
                     │      │        │
                     │  ┌───▼────┐  │
                     │  │  Rust  │  │
                     │  │ parse  │  │
                     │  │ report │  │
                     │  └────────┘  │
                     └──────────────┘
```

**Data flow:**
1. User interacts with React SPA via Go server (:8080)
2. GoBridge polls Go API every 5 seconds → fills LiveView assigns
3. LiveView pushes real-time updates to browser via WebSocket
4. Heavy CSV parsing runs in Rust NIF via DirtyScheduler (BEAM)
5. GenStage Pipeline fans out imported records to Go CRM via HTTP
6. Phoenix PubSub broadcasts state changes to all connected clients

---

## Features

### Core (MVP)

- [x] **Kanban Board** — 6 stages: Lead → Contact → Proposal → Negotiation → Closed Won / Lost
- [x] **Drag & Drop** — `phx-click` on card advances it to next stage
- [x] **Contact Manager** — CRUD: name, phone, email, company
- [x] **File Upload** — Multipart upload with size tracking
- [x] **REST API** — Full CRUD for tasks, contacts, files
- [x] **Embedded Frontend** — React SPA inside Go binary (`go:embed`)

### Dashboard (LiveView)

- [x] **Real-time Metrics** — Total deals, pipeline value, conversion rate, leads today
- [x] **Kanban Board** — Cards with title, amount, tags, source badge, priority dot
- [x] **Rust NIF Integration** — `generate_report` called every 15 seconds for pipeline scoring
- [x] **Import Pipeline** — CSV import via GenStage + Rust NIF with progress bar
- [x] **Go CRM Status** — Online/offline indicator with auto-reconnect banner
- [x] **Graceful Degradation** — Overlay when Go CRM is unreachable

### Enterprise

- [x] **GenStage Pipeline** — Producer → Consumer → Rust NIF → Go API
- [x] **Auto-Pipelines** — Workflow triggers on status change
- [x] **Multi-source** — Leads from Go CRM, Telegram Bot, CSV Import
- [x] **Tagging** — Auto-tags from title keywords

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **API / Backend** | Go 1.22 | REST API, SQLite, embedded React SPA |
| **Database** | SQLite (pure-Go) | Zero-dependency, portable, no install |
| **Dashboard** | Elixir + Phoenix LiveView | Real-time WebSocket, PubSub, GenStage |
| **Heavy CPU** | Rust + Rustler NIF | CSV parsing, report generation (DirtyScheduler) |
| **Frontend** | React 19 + Tailwind CSS 4 + Vite | Kanban, Contacts, Files UI |
| **Mobile** | Capacitor 6 | Android APK WebView wrapper |
| **ORM** | Ecto + SQLite3 | Elixir-side database for dashboard |
| **CI/CD** | GitHub Actions | Cross-platform builds (5 OS/arch) |

---

## Supported Platforms

| OS | Architecture | Binary | Size |
|----|-------------|--------|------|
| **Windows** | amd64 | `crm-server.exe` | ~15 MB |
| **Linux** | amd64 | `crm-server-linux` | ~15 MB |
| **macOS Intel** | amd64 | `crm-server-mac-intel` | ~15 MB |
| **macOS Apple Silicon** | arm64 | `crm-server-mac-arm64` | ~15 MB |
| **Linux ARM** | arm64 | `crm-server-linux-arm64` | ~15 MB |
| **Android** | arm64 | `app-debug.apk` | ~5 MB |

Built with `CGO_ENABLED=0` — no C compiler needed. Single static binary per platform.

---

## File Structure

```
crm/
├── main.go                  # Go entry point + go:embed frontend
├── internal/
│   ├── api/handler.go       # REST handlers (tasks, contacts, files)
│   └── db/db.go             # SQLite migrations (4 tables)
├── frontend/                # React SPA
│   ├── src/
│   │   ├── App.jsx          # Main app with tab navigation
│   │   ├── pages/
│   │   │   ├── Kanban.jsx   # Drag-drop board (4 columns)
│   │   │   ├── Contacts.jsx # Contact CRUD form + list
│   │   │   └── Files.jsx    # File upload + grid
│   │   └── index.css        # Tailwind CSS v4
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
├── dashboard/               # Elixir/Phoenix + Rust
│   ├── mix.exs              # Dependencies (Phoenix, Rustler, Ecto, GenStage)
│   ├── config/config.exs    # Ecto Repo, Go API URL, endpoint
│   ├── lib/
│   │   ├── crm/
│   │   │   ├── application.ex        # Supervisor (:one_for_one)
│   │   │   ├── repo.ex               # Ecto Repo (SQLite)
│   │   │   ├── native_bridge.ex      # Rust NIF bridge (use Rustler)
│   │   │   ├── go_bridge.ex          # HTTP client to Go API (GenServer)
│   │   │   ├── dashboard/live.ex     # LiveView: Kanban + Metrics + Import
│   │   │   ├── schemas/deal.ex       # Ecto schema (deals table)
│   │   │   └── pipeline/
│   │   │       ├── producer.ex       # GenStage Producer (CSV queue)
│   │   │       └── consumer.ex       # GenStage Consumer (Rust + Go API)
│   │   ├── crm_web.ex                # Phoenix macros
│   │   └── crm_web/
│   │       ├── endpoint.ex           # Phoenix Endpoint (:4000)
│   │       ├── router.ex             # Routes: / → DashboardLive
│   │       └── error_view.ex         # 404/500 error pages
│   ├── native/crm_native/
│   │   ├── Cargo.toml                # Rust crate (csv, chrono, serde_json)
│   │   └── src/lib.rs                # NIF: parse_csv, generate_report (DirtyCpu)
│   ├── priv/repo/migrations/
│   │   └── create_deals.exs          # Deals table migration
│   └── test/
│       └── crm_native_test.exs       # NIF integration test
├── mobile/                  # Capacitor Android
│   ├── package.json
│   └── capacitor.config.json
├── docker-compose.yml       # Go (:8080) + Phoenix (:4000)
├── Makefile                 # build, run, android, build-all, test
├── .github/workflows/
│   └── build.yml            # CI/CD: 5 OS cross-compile + upload artifacts
└── README.md
```

---

## API Reference

### Go CRM (:8080)

| Method | Path | Description | Body |
|--------|------|-------------|------|
| `GET` | `/api/health` | Health check | — |
| `GET` | `/api/tasks` | List all tasks | — |
| `POST` | `/api/tasks` | Create task | `{"title":"...","status":"todo"}` |
| `PUT` | `/api/tasks/:id` | Update task | `{"status":"in_progress"}` |
| `DELETE` | `/api/tasks/:id` | Delete task | — |
| `GET` | `/api/contacts` | List contacts | — |
| `POST` | `/api/contacts` | Create contact | `{"name":"...","phone":"..."}` |
| `PUT` | `/api/contacts/:id` | Update contact | `{"name":"..."}` |
| `DELETE` | `/api/contacts/:id` | Delete contact | — |
| `GET` | `/api/files` | List files | — |
| `POST` | `/api/files` | Upload file | Multipart: `file` field |

### Phoenix LiveView (:4000)

| Path | Description |
|------|-------------|
| `/` | Kanban dashboard (LiveView) |
| `/dashboard` | Same as `/` |

### Rust NIF (Internal)

```rust
// CSV parsing — DirtyCpu scheduler (>1ms)
fn parse_csv(path: &str) -> Vec<HashMap<String, String>>

// Report generation — DirtyCpu scheduler
fn generate_report(json: &str) -> String  // JSON output
```

---

## Build

### All Platforms (Cross-Compile)

```bash
make build-all
```

Produces:
```
crm-server.exe           # Windows amd64
crm-server-linux         # Linux amd64
crm-server-mac-intel     # macOS Intel
crm-server-mac-arm64     # macOS Apple Silicon (M1/M2/M3)
crm-server-linux-arm64   # Linux ARM64 (Raspberry Pi)
```

### Individual Platform

```bash
# Windows
go build -o crm-server.exe .

# Linux
GOOS=linux GOARCH=amd64 go build -o crm-server-linux .

# macOS Intel
GOOS=darwin GOARCH=amd64 go build -o crm-server-mac-intel .

# macOS M1/M2/M3
GOOS=darwin GOARCH=arm64 go build -o crm-server-mac-arm64 .

# Linux ARM64
GOOS=linux GOARCH=arm64 go build -o crm-server-linux-arm64 .
```

### Frontend Only

```bash
cd frontend && npm install && npm run build
```

Output: `frontend/dist/` (index.html + JS + CSS, ~300 KB)

### Dashboard Only

```bash
cd dashboard
mix deps.get          # Install dependencies
mix ecto.create       # Create SQLite database
mix ecto.migrate      # Run migrations
mix phx.server        # Start on :4000
```

### Android APK

```bash
cd mobile && npm install && npx cap add android && npx cap sync
cd mobile/android && ./gradlew assembleDebug
# APK: mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

### Docker

```bash
docker-compose up --build
```

Services:
- `go-crm` → :8080
- `dashboard` → :4000

---

## Development

### Run Go + React (with hot reload)

```bash
# Terminal 1: Go API
go run .

# Terminal 2: React dev server
cd frontend && npm run dev
# Open http://localhost:5173 (proxies /api to :8080)
```

### Run Phoenix (with hot reload)

```bash
cd dashboard && mix phx.server
# Open http://localhost:4000
```

### Run Tests

```bash
# Go tests
go test ./...

# Elixir tests
cd dashboard && mix test

# Rust tests
cd dashboard/native/crm_native && cargo test
```

### CI/CD (GitHub Actions)

On every push to `main`:
1. Build React frontend
2. Cross-compile Go for 5 platforms
3. Upload binaries as artifacts

Workflow: `.github/workflows/build.yml`

---

## Environment Variables

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `PORT` | `8080` | No | Go server port |
| `GO_API_URL` | `http://localhost:8080/api` | No | Phoenix GoBridge target |
| `BOT_TOKEN` | — | No (for auth) | Telegram bot token |

---

## License

MIT — [Leonov792/crm](https://github.com/Leonov792/crm)
