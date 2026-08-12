package api

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/google/uuid"
)

type Handler struct {
	db *sql.DB
}

func NewHandler(db *sql.DB) *Handler {
	return &Handler{db: db}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	// Tasks / Kanban
	mux.HandleFunc("/api/tasks", h.handleTasks)
	mux.HandleFunc("/api/tasks/", h.handleTaskByID)

	// Contacts
	mux.HandleFunc("/api/contacts", h.handleContacts)
	mux.HandleFunc("/api/contacts/", h.handleContactByID)

	// Files
	mux.HandleFunc("/api/files", h.handleFiles)

	// Health
	mux.HandleFunc("/api/health", h.handleHealth)
}

// =====================================================================
// HEALTH
// =====================================================================

func (h *Handler) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]interface{}{
		"status": "ok",
		"name":   "CRM Server",
		"db":     "sqlite",
	})
}

// =====================================================================
// TASKS (KANBAN)
// =====================================================================

func (h *Handler) handleTasks(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		rows, err := h.db.Query(`SELECT id, title, description, status, priority, assignee, due_date, board_order, created_at FROM tasks ORDER BY board_order ASC`)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		defer rows.Close()

		var tasks []map[string]interface{}
		for rows.Next() {
			var id, title, desc, status, priority, assignee, due, createdAt string
			var order int
			rows.Scan(&id, &title, &desc, &status, &priority, &assignee, &due, &order, &createdAt)
			tasks = append(tasks, map[string]interface{}{
				"id": id, "title": title, "description": desc, "status": status,
				"priority": priority, "assignee": assignee, "due_date": due,
				"board_order": order, "created_at": createdAt,
			})
		}
		writeJSON(w, tasks)

	case "POST":
		var t struct {
			Title       string `json:"title"`
			Description string `json:"description"`
			Status      string `json:"status"`
			Priority    string `json:"priority"`
			Assignee    string `json:"assignee"`
			DueDate     string `json:"due_date"`
		}
		json.NewDecoder(r.Body).Decode(&t)
		if t.Status == "" {
			t.Status = "todo"
		}
		id := uuid.New().String()
		_, err := h.db.Exec(`INSERT INTO tasks (id, title, description, status, priority, assignee, due_date) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			id, t.Title, t.Description, t.Status, t.Priority, t.Assignee, t.DueDate)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		writeJSON(w, map[string]string{"id": id, "status": t.Status})

	default:
		w.WriteHeader(405)
	}
}

func (h *Handler) handleTaskByID(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/tasks/")
	if id == "" {
		w.WriteHeader(400)
		return
	}

	switch r.Method {
	case "PUT":
		var t struct {
			Title       string `json:"title"`
			Description string `json:"description"`
			Status      string `json:"status"`
			Priority    string `json:"priority"`
			Assignee    string `json:"assignee"`
			BoardOrder  int    `json:"board_order"`
		}
		json.NewDecoder(r.Body).Decode(&t)

		_, err := h.db.Exec(`UPDATE tasks SET title=$1, description=$2, status=$3, priority=$4, assignee=$5, board_order=$6, updated_at=datetime('now') WHERE id=$7`,
			t.Title, t.Description, t.Status, t.Priority, t.Assignee, t.BoardOrder, id)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		writeJSON(w, map[string]string{"id": id, "updated": "ok"})

	case "DELETE":
		h.db.Exec(`DELETE FROM tasks WHERE id=$1`, id)
		writeJSON(w, map[string]string{"deleted": id})

	default:
		w.WriteHeader(405)
	}
}

// =====================================================================
// CONTACTS
// =====================================================================

func (h *Handler) handleContacts(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		rows, err := h.db.Query(`SELECT id, name, phone, email, company, notes, created_at FROM contacts ORDER BY name ASC`)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		defer rows.Close()

		var contacts []map[string]interface{}
		for rows.Next() {
			var id, name, phone, email, company, notes, createdAt string
			rows.Scan(&id, &name, &phone, &email, &company, &notes, &createdAt)
			contacts = append(contacts, map[string]interface{}{
				"id": id, "name": name, "phone": phone, "email": email,
				"company": company, "notes": notes, "created_at": createdAt,
			})
		}
		writeJSON(w, contacts)

	case "POST":
		var c struct {
			Name    string `json:"name"`
			Phone   string `json:"phone"`
			Email   string `json:"email"`
			Company string `json:"company"`
			Notes   string `json:"notes"`
		}
		json.NewDecoder(r.Body).Decode(&c)
		id := uuid.New().String()
		h.db.Exec(`INSERT INTO contacts (id, name, phone, email, company, notes) VALUES ($1,$2,$3,$4,$5,$6)`,
			id, c.Name, c.Phone, c.Email, c.Company, c.Notes)
		writeJSON(w, map[string]string{"id": id})

	default:
		w.WriteHeader(405)
	}
}

func (h *Handler) handleContactByID(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/contacts/")
	if id == "" {
		w.WriteHeader(400)
		return
	}

	switch r.Method {
	case "PUT":
		var c struct {
			Name    string `json:"name"`
			Phone   string `json:"phone"`
			Email   string `json:"email"`
			Company string `json:"company"`
			Notes   string `json:"notes"`
		}
		json.NewDecoder(r.Body).Decode(&c)
		h.db.Exec(`UPDATE contacts SET name=$1, phone=$2, email=$3, company=$4, notes=$5 WHERE id=$6`,
			c.Name, c.Phone, c.Email, c.Company, c.Notes, id)
		writeJSON(w, map[string]string{"updated": "ok"})

	case "DELETE":
		h.db.Exec(`DELETE FROM contacts WHERE id=$1`, id)
		writeJSON(w, map[string]string{"deleted": id})

	default:
		w.WriteHeader(405)
	}
}

// =====================================================================
// FILES
// =====================================================================

func (h *Handler) handleFiles(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		rows, _ := h.db.Query(`SELECT id, name, size, type, uploaded_at FROM files ORDER BY uploaded_at DESC`)
		defer rows.Close()
		var files []map[string]interface{}
		for rows.Next() {
			var id, name, ftype, uploaded string
			var size int64
			rows.Scan(&id, &name, &size, &ftype, &uploaded)
			files = append(files, map[string]interface{}{
				"id": id, "name": name, "size": size, "type": ftype, "uploaded_at": uploaded,
			})
		}
		writeJSON(w, files)

	case "POST":
		r.ParseMultipartForm(10 << 20) // 10MB
		file, header, err := r.FormFile("file")
		if err != nil {
			writeJSON(w, map[string]string{"error": "file required"})
			return
		}
		defer file.Close()

		id := uuid.New().String()
		_, err = h.db.Exec(`INSERT INTO files (id, name, size, type) VALUES ($1,$2,$3,$4)`,
			id, header.Filename, header.Size, header.Header.Get("Content-Type"))
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		writeJSON(w, map[string]interface{}{"id": id, "name": header.Filename, "size": header.Size})

	default:
		w.WriteHeader(405)
	}
}

// =====================================================================
// HELPERS
// =====================================================================

func writeJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
