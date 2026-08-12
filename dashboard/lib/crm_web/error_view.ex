defmodule CrmWeb.ErrorView do
  use Phoenix.Component

  def render("404.html", _assigns) do
    "<div style='padding:40px;text-align:center;color:#848E9C'><h1>404</h1></div>"
  end

  def render("500.html", _assigns) do
    "<div style='padding:40px;text-align:center;color:#848E9C'><h1>500</h1></div>"
  end
end
