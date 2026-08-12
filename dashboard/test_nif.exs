# Test script for Rust NIF
Code.require_file("lib/crm/native_bridge.ex")

IO.puts("=== NIF TEST START ===")

# Test 1: generate_report
json = Jason.encode!(%{tasks_count: 10, contacts_count: 20})
IO.puts("Input: #{json}")

result = Crm.NativeBridge.generate_report(json)
case result do
  {:ok, report} ->
    IO.puts("PASS: generate_report returned #{map_size(report)} keys")
    IO.puts("  tasks: #{report["tasks"]}")
    IO.puts("  contacts: #{report["contacts"]}")
    IO.puts("  engine: #{report["engine"]}")
  {:error, reason} ->
    IO.puts("FAIL: #{inspect(reason)}")
  other ->
    IO.puts("UNEXPECTED: #{inspect(other)}")
end

# Test 2: parse_csv (with fake path)
csv_result = Crm.NativeBridge.parse_csv("/nonexistent/test.csv")
IO.puts("parse_csv (no file): #{inspect(csv_result)}")

IO.puts("=== NIF TEST END ===")
