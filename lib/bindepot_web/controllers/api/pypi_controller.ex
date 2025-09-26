defmodule BindepotWeb.Api.PypiController do
  use BindepotWeb, :controller

  defp wants_pep691_json?(conn) do
    accept = Enum.join(get_req_header(conn, "accept"), ",")
    query = conn.query_params

    cond do
      Map.get(query, "format") == "json" -> true
      String.contains?(accept, "application/vnd.pypi.simple.v1+json") -> true
      true -> false
    end
  end

  defp json_content_type, do: "application/vnd.pypi.simple.v1+json"

  def simple_index(conn, %{ "repository" => repository }) do
    body = "test"
    conn |> put_resp_content_type("text/html") |> send_resp(200, "<html><body>\n" <> body <> "\n</body></html>")
  end

  def project_index(conn, %{"name" => name}) do
    conn |> put_resp_content_type("text/html") |> send_resp(200, "<html><body>\n" <> name <> "\n</body></html>")
  end

  def serve_package(conn, %{"project" => project, "version" => version, "filename" => filename}) do
    conn |> put_resp_content_type("text/html") |> send_resp(200, "<html><body>\n" <> filename <> "\n</body></html>")
  end

  def serve_metadata(conn, %{"project" => project, "version" => version, "filename" => _filename}) do
    conn |> put_resp_content_type("text/plain") |> send_resp(200, "metadata")
  end

  def legacy_upload(conn, params) do
    conn |> put_resp_content_type("application/json") |> send_resp(200, Jason.encode!(%{ok: true, id: 1}))
  end

end
