defmodule CrmWeb do
  @moduledoc """
  Phoenix endpoint для CRM дашборда.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: CrmWeb
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.HTML
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: false
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
