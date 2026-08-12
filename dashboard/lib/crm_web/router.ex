defmodule CrmWeb.Router do
  use CrmWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", CrmWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/dashboard", DashboardLive, :index
  end
end
