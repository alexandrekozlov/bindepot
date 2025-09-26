defmodule BindepotWeb.Api.RepositoryController do
  use BindepotWeb, :controller

  def create_repository(conn, %{ "repository" => repository }) do
    conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "Hello, here is your #{repository}")
  end

  def delete_repository(conn, %{ "repository" => repository }) do
    conn
      |> send_resp(200, "OK")
  end

end
