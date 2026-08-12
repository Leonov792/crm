package db

import (
	"database/sql"
	"log"

	_ "modernc.org/sqlite"
)

func Init(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path+"?_journal_mode=WAL&_foreign_keys=on")
	if err != nil {
		return nil, err
	}

	db.SetMaxOpenConns(1) // SQLite single writer

	if err := migrate(db); err != nil {
		return nil, err
	}

	return db, nil
}

func migrate(db *sql.DB) error {
	statements := []string{
		`CREATE TABLE IF NOT EXISTS tasks (
			id TEXT PRIMARY KEY,
			title TEXT NOT NULL,
			description TEXT DEFAULT '',
			status TEXT DEFAULT 'todo',
			priority TEXT DEFAULT 'medium',
			assignee TEXT DEFAULT '',
			due_date TEXT DEFAULT '',
			board_order INTEGER DEFAULT 0,
			created_at TEXT DEFAULT (datetime('now')),
			updated_at TEXT DEFAULT (datetime('now'))
		)`,
		`CREATE TABLE IF NOT EXISTS contacts (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			phone TEXT DEFAULT '',
			email TEXT DEFAULT '',
			company TEXT DEFAULT '',
			notes TEXT DEFAULT '',
			created_at TEXT DEFAULT (datetime('now'))
		)`,
		`CREATE TABLE IF NOT EXISTS files (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			size INTEGER DEFAULT 0,
			type TEXT DEFAULT '',
			path TEXT DEFAULT '',
			task_id TEXT DEFAULT '',
			uploaded_at TEXT DEFAULT (datetime('now'))
		)`,
		`CREATE TABLE IF NOT EXISTS pipelines (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			steps TEXT DEFAULT '[]',
			enabled INTEGER DEFAULT 1,
			created_at TEXT DEFAULT (datetime('now'))
		)`,
	}

	for _, s := range statements {
		if _, err := db.Exec(s); err != nil {
			return err
		}
	}

	log.Println("Database migrated")
	return nil
}
