defmodule BindepotWeb.Plugs.GetRepository do

  import Plug.Conn
  alias Bindepot.Core.Repositories

  def init(opts), do: opts

  def call(%Plug.Conn{params: %{"repo" => repo_key}} = conn, _opts) do
    repository = Repositories.get_by_name(repo_key)
    case repository do
      nil ->
        conn
        |> send_resp(404, "repository not found")
        |> halt()

      _ ->
        assign(conn, :repository, repository)
    end
  end

  def call(conn, _opts), do: conn
end
