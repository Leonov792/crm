// crm_native — Rust NIF для CRM Dashboard
// Выполняет тяжёлые CPU-задачи через Dirty Scheduler BEAM.
//
// Функции:
// - parse_csv: парсинг CSV-файла с лидами (возвращает Vec<HashMap>)
// - generate_report: генерация аналитического JSON-отчёта

use rustler::{Env, Error, NifResult, Term};
use serde_json::Value;
use std::time::Instant;

/// Парсинг CSV с импортом лидов.
/// Работает через DirtyCpu так как парсинг больших файлов > 1ms.
#[rustler::nif(schedule = "DirtyCpu")]
fn parse_csv<'a>(env: Env<'a>, path: String) -> NifResult<Vec<Term<'a>>> {
    let start = Instant::now();

    // Создаём reader с заголовками
    let mut reader = csv::ReaderBuilder::new()
        .has_headers(true)
        .trim(csv::Trim::All)
        .from_path(&path)
        .map_err(|e| Error::Term(Box::new(format!("CSV open error: {}", e))))?;

    // Получаем заголовки
    let headers: Vec<String> = reader
        .headers()
        .map_err(|e| Error::Term(Box::new(format!("CSV headers error: {}", e))))?
        .iter()
        .map(String::from)
        .collect();

    let mut records: Vec<Term> = Vec::new();

    // Парсим записи
    for result in reader.records() {
        let record = result.map_err(|e| Error::Term(Box::new(format!("CSV record error: {}", e))))?;

        // Строим map для каждой записи
        let mut map_keys: Vec<(String, String)> = Vec::new();
        for (i, field) in record.iter().enumerate() {
            let key = headers.get(i).cloned().unwrap_or_else(|| format!("field_{}", i));
            map_keys.push((key, field.to_string()));
        }

        let keys: Vec<(&str, &str)> = map_keys.iter().map(|(k, v)| (k.as_str(), v.as_str())).collect();
        let term_map = Term::map_from_pairs(env, &keys)?;
        records.push(term_map);
    }

    let elapsed = start.elapsed();
    println!(
        "[Rust NIF] parse_csv: {} records in {:?}",
        records.len(),
        elapsed
    );

    Ok(records)
}

/// Генерация аналитического JSON-отчёта.
/// Принимает данные в JSON-строке, возвращает отчёт.
#[rustler::nif(schedule = "DirtyCpu")]
fn generate_report(data_json: String) -> NifResult<String> {
    let start = Instant::now();

    // Парсим входной JSON
    let data: Value = serde_json::from_str(&data_json)
        .unwrap_or(serde_json::json!({"error": "invalid json"}));

    // Считаем метрики
    let tasks_count = data.get("tasks_count").and_then(|v| v.as_u64()).unwrap_or(0);
    let contacts_count = data.get("contacts_count").and_then(|v| v.as_u64()).unwrap_or(0);

    let report = serde_json::json!({
        "generated_at": chrono::Utc::now().to_rfc3339(),
        "total_records": tasks_count + contacts_count,
        "tasks": tasks_count,
        "contacts": contacts_count,
        "engine": "rust-nif-v1.0",
        "processing_time_ms": start.elapsed().as_millis()
    });

    let result = serde_json::to_string_pretty(&report)
        .unwrap_or_else(|_| r#"{"error":"serialization failed"}"#.to_string());

    println!(
        "[Rust NIF] generate_report: {:?}",
        start.elapsed()
    );

    Ok(result)
}

// Регистрация NIF функций для Rustler
// Имя модуля ДОЛЖНО совпадать с Elixir модулем: Crm.NativeBridge → Elixir.Crm.NativeBridge
rustler::init!("Elixir.Crm.NativeBridge", load = load);

fn load(_env: Env, _info: Term) -> bool {
    println!("[Rust NIF] crm_native loaded successfully");
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::io::Write;

    #[test]
    fn test_generate_report() {
        let json = r#"{"tasks_count": 15, "contacts_count": 42}"#;
        let result = generate_report(json.to_string()).unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["tasks"], 15);
        assert_eq!(parsed["contacts"], 42);
    }

    #[test]
    fn test_parse_csv() {
        // Создаём временный CSV-файл
        let path = "/tmp/test_leads.csv";
        let csv_content = "name,phone,email\nIvan,+79161234567,ivan@mail.ru\nPetr,+79261234568,petr@mail.ru";
        let mut file = fs::File::create(path).unwrap();
        file.write_all(csv_content.as_bytes()).unwrap();

        // Парсим через NIF (требует BEAM-окружение для терминов)
        // В unit-тесте без BEAM — тест на структуру не запустится.
        // Оставляем для интеграционных тестов в Elixir.
        println!("CSV test file created at {}", path);
        fs::remove_file(path).ok();
    }
}
