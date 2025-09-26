defmodule Bindepot.Repository.Controllers.RpmController do
  @moduledoc """
  Controller module serving a mock RPM/YUM repository API.

  Example router wiring (put into your `router.ex`):

      scope "/api", BindepotWeb do
        pipe_through :api
        scope "/rpm", Bindepot.Repository.Controllers.RpmController do
          get  "/", :index               # list packages
          get  "/:name", :show           # package metadata / versions
          get  "/:name/:version/:arch/download", :download
          get  "/repodata/repomd.xml", :repomd
          post "/upload", :upload_multipart   # multipart/form-data upload
          put  "/upload/:name/:version/:arch", :upload_raw
        end
      end

  Curl examples (against host http://localhost:4000):

  - List packages:
      curl -i http://localhost:4000/api/rpm/

  - Get package metadata:
      curl -i http://localhost:4000/api/rpm/bash

  - Download package:
      curl -i -O http://localhost:4000/api/rpm/bash/5.0.0/x86_64/download

  - Download repomd.xml:
      curl -i http://localhost:4000/api/rpm/repodata/repomd.xml

  - Upload multipart (multipart/form-data, field name "package"):
      curl -i -F "package=@/path/to/some.rpm" http://localhost:4000/api/rpm/upload

  - Upload raw (PUT with raw body):
      curl -i -X PUT --data-binary "@/path/to/some.rpm" \
        -H "Content-Type: application/x-rpm" \
        http://localhost:4000/api/rpm/upload/bash/1.2.3/x86_64
  """

  use Phoenix.Controller

  @fake_rpm_content "FAKE-RPM-BINARY-CONTENT\n"
  @fake_repomd """
  <?xml version="1.0" encoding="UTF-8"?>
  <repomd>
    <data type="primary">
      <location href="repodata/primary.xml.gz"/>
      <checksum type="sha256">deadbeef</checksum>
    </data>
  </repomd>
  """

  # ------------------------------------------------------------------
  # Public endpoints (mock implementations)
  # ------------------------------------------------------------------

  @doc """
  GET /api/rpm/
  Returns a mocked list of packages available in repository.
  """
  def index(conn, _params) do
    packages = [
      %{
        name: "bash",
        latest_version: "5.0.0",
        architectures: ["x86_64", "aarch64"]
      },
      %{
        name: "openssl",
        latest_version: "3.1.1",
        architectures: ["x86_64"]
      }
    ]

    conn
    |> put_resp_content_type("application/json")
    |> json(%{ok: true, packages: packages})
  end

  @doc """
  GET /api/rpm/:name
  Returns mocked metadata for a named package (versions/arches).
  """
  def show(conn, %{"name" => name}) do
    # mock: two versions for any package name
    metadata = %{
      name: name,
      versions: [
        %{
          version: "5.0.0",
          release: "1",
          archs: ["x86_64", "aarch64"],
          filename: "#{name}-5.0.0-1.x86_64.rpm"
        },
        %{
          version: "4.9.1",
          release: "2",
          archs: ["x86_64"],
          filename: "#{name}-4.9.1-2.x86_64.rpm"
        }
      ]
    }

    conn
    |> put_resp_content_type("application/json")
    |> json(%{ok: true, metadata: metadata})
  end

  @doc """
  GET /api/rpm/:name/:version/:arch/download
  Returns a fake RPM binary with appropriate headers to trigger download.
  """
  def download(conn, %{"name" => name, "version" => version, "arch" => arch}) do
    filename = "#{name}-#{version}.#{arch}.rpm"
    body = build_fake_rpm(name, version, arch)

    conn
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> put_resp_content_type("application/x-rpm")
    |> send_resp(200, body)
  end

  @doc """
  GET /api/rpm/repodata/repomd.xml
  Returns a mocked repomd.xml for YUM repository metadata.
  """
  def repomd(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, @fake_repomd)
  end

  @doc """
  POST /api/rpm/upload
  Accepts multipart/form-data with field "package" (Plug.Upload).
  Responds with JSON metadata echoing the upload fields. This is a mock:
  the uploaded file is not saved permanently here (but the Plug.Upload.path
  can be inspected if you want to move it into real storage).
  """
  def upload_multipart(conn, _params) do
    # Phoenix/Plug will already have parsed multipart bodies into params with %Plug.Upload
    # Attempt to get upload under "package" or "file"
    upload =
      conn.params["package"] ||
        conn.params["file"] ||
        find_first_upload(conn.params)

    case upload do
      %Plug.Upload{} = up ->
        # Inspect a little metadata and echo it back
        resp = %{
          ok: true,
          message: "mock multipart upload accepted",
          filename: up.filename,
          content_type: up.content_type,
          temp_path: up.path
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(201, Jason.encode!(resp))

      nil ->
        conn
        |> put_status(400)
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{ok: false, error: "no file field 'package' or 'file' found"}))
    end
  end

  @doc """
  PUT /api/rpm/upload/:name/:version/:arch

  Accepts raw request body for RPM binary uploads. This endpoint will read
  the raw body stream (via Plug.Conn.read_body/2) and respond with an acknowledgment.
  This mock doesn't persist the binary beyond echoing its size.
  """
  def upload_raw(conn, %{"name" => name, "version" => version, "arch" => arch} = _params) do
    # read raw body, with sensible limits for mock (you can tune timeout and length)
    case read_body_safe(conn) do
      {:ok, body, conn} ->
        resp = %{
          ok: true,
          message: "mock raw upload accepted",
          name: name,
          version: version,
          arch: arch,
          bytes_received: byte_size(body)
        }

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(201, Jason.encode!(resp))

      {:more, _partial, _conn} ->
        conn
        |> put_status(413)
        |> put_resp_content_type("application/json")
        |> send_resp(413, Jason.encode!(%{ok: false, error: "payload too large or streaming not supported in mock"}))

      {:error, reason} ->
        conn
        |> put_status(500)
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{ok: false, error: inspect(reason)}))
    end
  end

  # ------------------------------------------------------------------
  # Helper functions
  # ------------------------------------------------------------------

  defp build_fake_rpm(name, version, arch) do
    [
      "RPM-MOCK\n",
      "Name: ", name, "\n",
      "Version: ", version, "\n",
      "Arch: ", arch, "\n",
      @fake_rpm_content
    ]
    |> IO.iodata_to_binary()
  end

  # Try to find a Plug.Upload value nested in params map
  defp find_first_upload(params) when is_map(params) do
    params
    |> Map.values()
    |> Enum.find(fn
      %Plug.Upload{} -> true
      %{} = m -> find_first_upload(m)
      _ -> false
    end)
  end

  defp find_first_upload(_), do: nil

  # Safely read body with moderate length limit and timeout.
  # Adjust :length and :read_length if you expect large uploads and implement streaming.
  defp read_body_safe(conn) do
    # Options:
    #   length: max bytes to read (here 50MB)
    #   read_length: bytes to read per chunk (not used if body small)
    #   read_timeout: ms
    opts = [length: 50_000_000, read_length: 1_000_000, read_timeout: 60_000]
    Plug.Conn.read_body(conn, opts)
  end
end
