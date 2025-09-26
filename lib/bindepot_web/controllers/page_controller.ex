defmodule BindepotWeb.PageController do
  use BindepotWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
