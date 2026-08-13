package main

import (
	"crm/internal/api"
	"crm/internal/db"
	"embed"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"time"
)

//go:embed frontend/dist
var frontendFS embed.FS

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	database, err := db.Init("crm.db")
	if err != nil {
		fmt.Println("============================================")
		fmt.Println("  ERROR: Cannot create database crm.db")
		fmt.Println("  " + err.Error())
		fmt.Println("  Move the executable to a writable folder")
		fmt.Println("  (Desktop or Home directory).")
		fmt.Println("  On Linux/macOS: chmod 755 crm-server")
		fmt.Println("============================================")
		fmt.Println()
		fmt.Println("Press Enter to close...")
		fmt.Scanln()
		return
	}
	defer database.Close()

	mux := http.NewServeMux()
	apiHandler := api.NewHandler(database)
	apiHandler.RegisterRoutes(mux)

	distFS, err := fs.Sub(frontendFS, "frontend/dist")
	if err != nil {
		log.Printf("Frontend not embedded: %v", err)
	} else {
		mux.Handle("/", http.FileServer(http.FS(distFS)))
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	url := "http://localhost:" + port

	// Авто-открытие браузера через 1 секунду после старта
	go func() {
		time.Sleep(1 * time.Second)
		openBrowser(url)
	}()

	fmt.Println("============================================")
	fmt.Println("  CRM SERVER RUNNING")
	fmt.Println("  Open in browser: " + url)
	fmt.Println("  (Browser should open automatically)")
	fmt.Println()
	fmt.Println("  Press Ctrl+C to stop the server")
	fmt.Println("============================================")

	if err := http.ListenAndServe(":"+port, corsMiddleware(mux)); err != nil {
		fmt.Println()
		fmt.Println("============================================")
		fmt.Println("  ERROR: Port " + port + " is already in use")
		fmt.Println("  Close other programs or change the port:")
		fmt.Println("  Linux/Mac: export PORT=9000 && ./crm-server")
		fmt.Println("  Windows:   set PORT=9000 && crm-server.exe")
		fmt.Println("============================================")
		fmt.Println()
		fmt.Println("Press Enter to close...")
		fmt.Scanln()
	}
}

func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	_ = cmd.Start()
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "*")
		if r.Method == "OPTIONS" {
			w.WriteHeader(200)
			return
		}
		next.ServeHTTP(w, r)
	})
}
