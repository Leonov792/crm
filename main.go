package main

import (
	"crm/internal/api"
	"crm/internal/db"
	"embed"
	"io/fs"
	"log"
	"net/http"
	"os"
)

//go:embed frontend/dist
var frontendFS embed.FS

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	database, err := db.Init("crm.db")
	if err != nil {
		log.Fatalf("Database: %v", err)
	}
	defer database.Close()
	log.Println("SQLite initialized")

	mux := http.NewServeMux()
	apiHandler := api.NewHandler(database)
	apiHandler.RegisterRoutes(mux)

	distFS, err := fs.Sub(frontendFS, "frontend/dist")
	if err != nil {
		log.Printf("Frontend not embedded (dev mode): %v", err)
	} else {
		fileServer := http.FileServer(http.FS(distFS))
		mux.Handle("/", fileServer)
		log.Println("Frontend embedded")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("CRM Server starting on http://localhost:%s", port)
	if err := http.ListenAndServe(":"+port, corsMiddleware(mux)); err != nil {
		log.Fatalf("Server: %v", err)
	}
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
