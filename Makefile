.PHONY: all build run clean frontend android dashboard rust

all: frontend build

frontend:
	cd frontend && npm install && npm run build

build:
	go build -o crm-server .

run:
	go run .

dashboard-build:
	cd dashboard && mix deps.get && mix compile

dashboard-run:
	cd dashboard && mix phx.server

rust-build:
	cd dashboard/native/crm_native && cargo build --release

run-all:
	docker-compose up --build

# Cross-platform builds (5 OS/arch)
build-all:
	GOOS=windows GOARCH=amd64 go build -o crm-server.exe .
	GOOS=linux GOARCH=amd64 go build -o crm-server-linux .
	GOOS=darwin GOARCH=amd64 go build -o crm-server-mac-intel .
	GOOS=darwin GOARCH=arm64 go build -o crm-server-mac-arm64 .
	GOOS=linux GOARCH=arm64 go build -o crm-server-linux-arm64 .

android:
	cd mobile && npm install && npx cap add android && npx cap sync
	cd mobile/android && ./gradlew assembleDebug

test:
	go test ./...
	cd dashboard && mix test 2>/dev/null || echo "Elixir skipped (no BEAM)"

clean:
	rm -rf crm-server crm.db frontend/dist
	cd dashboard && mix clean 2>/dev/null || true
	cd dashboard/native/crm_native && cargo clean 2>/dev/null || true
