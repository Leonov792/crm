defmodule Crm.NativeBridge do
  @moduledoc """
  Мост между Elixir и Rust NIF через Rustler.
  Все тяжёлые CPU-операции вызываются через грязный планировщик BEAM.

  Функции:
  - parse_csv/1 — парсинг CSV-файла с лидами
  - generate_report/1 — генерация аналитического отчёта
  """

  # Rustler 0.38: define NIF module directly
  use Rustler, otp_app: :crm_dashboard, crate: :crm_native

  # NIF-функции объявлены как заглушки — Rustler заменяет их при компиляции
  def parse_csv(_path), do: err()
  def generate_report(_data), do: err()

  defp err, do: :erlang.nif_error(:nif_not_loaded)
end
