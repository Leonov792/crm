defmodule CrmWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :crm_dashboard, render_errors: [html: CrmWeb.ErrorHTML, layout: false]

  socket "/live", Phoenix.LiveView.Socket

  plug CrmWeb.Router
end
