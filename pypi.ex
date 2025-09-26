# File: lib/bindepot/repository/controllers/pypi_controller.ex
defmodule Bindepot.Repository.Controllers.PypiController do
  @moduledoc """
  Controller implementing PyPI-compatible APIs and upload endpoints.

  Supported PEPs / features (mock/persistent implementations included):

  * PEP 503 — Simple Repository API (HTML simple index and per-project pages).
  * PEP 691 — JSON Simple API (application/vnd.pypi.simple.v1+json).
  * PEP 658 — Distribution metadata anchors in the simple API (dist-info METADATA exposure).
  * PEP 629 — Recording project release metadata (standardizing how release metadata is recorded and exposed).
  * PEP 592 — JSON-based package metadata format (metadata v2.x JSON recommendations / machine-readable metadata).
  * PEP 592 complements METADATA text by allowing structured JSON payloads; controller/context provide a JSON metadata map
    for releases and expose METADATA text derived from that map for backward compatibility.

  The controller supports the following endpoints (router snippet):

      scope "/pypi", BindepotWeb do
        pipe_through :browser

        get "/simple/", PypiController, :simple_index
        get "/simple/:name/", PypiController, :project_index

        get "/packages/:project/:version/:filename", PypiController, :serve_package
        get "/packages/:project/:version/:filename/METADATA", PypiController, :serve_metadata

        post "/legacy/", PypiController, :legacy_upload
        post "/pypi", PypiController, :xmlrpc
      end

  Implementation notes for added PEPs:

  * PEP 658 (already present): distribution anchors include `data-dist-info-metadata` attributes in HTML and
    `dist-info-metadata` fields in PEP 691 JSON so tools can retrieve metadata without downloading full distributions.

  * PEP 629 (Release metadata recording): the `Release` Ecto schema stores `metadata` as a JSON/map column. This
    aligns with PEP 629's goal to have standardized, queryable release metadata. The controller/context expose
    builders that return metadata both as structured JSON (for PEP 592-style clients) and as legacy METADATA text
    for `pip`/`setuptools` compatibility.

  * PEP 592 (JSON metadata): where available the `Release.metadata` map is included directly in project JSON responses
    (PEP 691 `files` entries include `requires-python` and other metadata). The `serve_metadata` endpoint will render
    a textual METADATA representation derived from the structured metadata map so older clients keep working.

  PEP references (useful links):

  * PEP 503 — Simple Repository API
    https://peps.python.org/pep-0503/
  * PEP 691 — JSON-based Simple Repository API
    https://peps.python.org/pep-0691/
  * PEP 658 — Exposing distribution metadata in the simple API
    https://peps.python.org/pep-0658/
  * PEP 629 — Recording project metadata in repository backends (Release metadata best-practices)
    https://peps.python.org/pep-0629/
  * PEP 592 — JSON-based package metadata (structured metadata)
    https://peps.python.org/pep-0592/

  """


  use BindepotWeb, :controller
  alias Bindepot.Repository
  alias Bindepot.Repository.{Package,Release,DistFile}

  # Content negotiation helpers and auth similar to previous mock implementation
  defp allowed_tokens do
    Application.get_env(:bindepot, __MODULE__, [])
    |> Keyword.get(:api_tokens, ["mock-token"])
  end

  defp require_auth_for_index? do
    Application.get_env(:bindepot, __MODULE__, [])
    |> Keyword.get(:require_auth_for_index, false)
  end

  defp extract_token_from_conn(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      [basic] ->
        case String.split(basic, " ", parts: 2) do
          ["Basic", b64] ->
            case Base.decode64(b64) do
              {:ok, creds} ->
                case String.split(creds, ":", parts: 2) do
                  [_user, pass] -> pass
                  _ -> nil
                end
              _ -> nil
            end
          _ -> nil
        end
      _ -> nil
    end
  end

  defp valid_token?(token) when is_binary(token) do
    Enum.any?(allowed_tokens(), fn t -> Plug.Crypto.secure_compare(t, token) end)
  end
  defp valid_token?(_), do: false

  defp require_auth!(conn) do
    token = extract_token_from_conn(conn)

    if valid_token?(token) do
      {:ok, conn}
    else
      conn
      |> put_resp_header("www-authenticate", "Basic realm=\"Bindepot\"")
      |> send_resp(401, "Unauthorized")
      |> halt()
    end
  end

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

  # ----------------- Index endpoints -----------------
  def simple_index(conn, _params) do
    if require_auth_for_index?(), do: require_auth!(conn)
    if conn.halted, do: conn, else: do_simple_index(conn)
  end

  defp do_simple_index(conn) do
    if wants_pep691_json?(conn) do
      body = Repository.build_index_json() |> Jason.encode!()
      conn |> put_resp_content_type(json_content_type()) |> send_resp(200, body)
    else
      projects = Repository.list_package_names()
      body = Enum.map(projects, fn name -> "<a href=\"/pypi/simple/#{URI.encode_www_form(name)}/\">#{name}</a><br/>" end) |> Enum.join("\n")
      conn |> put_resp_content_type("text/html") |> send_resp(200, "<html><body>\n" <> body <> "\n</body></html>")
    end
  end

  def project_index(conn, %{"name" => name}) do
    if require_auth_for_index?(), do: require_auth!(conn)
    if conn.halted, do: conn, else: do_project_index(conn, name)
  end

  defp do_project_index(conn, name) do
    if wants_pep691_json?(conn) do
      case Repository.build_project_json(name) do
        nil -> conn |> put_resp_content_type(json_content_type()) |> send_resp(404, Jason.encode!(%{"error" => "not found"}))
        json -> conn |> put_resp_content_type(json_content_type()) |> send_resp(200, Jason.encode!(json))
      end
    else
      case Repository.get_project_with_releases(name) do
        nil -> send_resp(conn, 404, "Project not found")
        %{package: pkg, releases: releases} ->
          html =
            releases
            |> Enum.map(fn r ->
              files_html =
                r.dist_files
                |> Enum.map(fn f ->
                  meta_url = f.url <> "/METADATA"
                  "<a href=\"#{f.url}\" data-dist-info-metadata=\"#{meta_url}\">#{f.filename}</a>"
                end)
                |> Enum.join("<br/>\n")

              "<h3>#{r.version}</h3>\n" <> files_html
            end)
            |> Enum.join("\n<hr/>\n")

          body = "<html><body>\n<h1>Links for #{pkg.name}</h1>\n" <> html <> "\n</body></html>"
          conn |> put_resp_content_type("text/html") |> send_resp(200, body)
      end
    end
  end

  # ----------------- Serve package and metadata -----------------
  def serve_package(conn, %{"project" => project, "version" => version, "filename" => filename}) do
    # In this example we redirect to storage URL if present or stream a mock
    case Repository.get_distribution_file(project, version, filename) do
      nil -> send_resp(conn, 404, "Not found")
      %{url: url} when is_binary(url) and String.starts_with?(url, "http") -> redirect(conn, external: url)
      %{path: path} when is_binary(path) and File.exists?(path) ->
        conn
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_file(200, path)
      _ ->
        conn
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> put_resp_content_type("application/octet-stream")
        |> send_resp(200, "MOCK CONTENT for #{project} #{version} #{filename}\n")
    end
  end

  def serve_metadata(conn, %{"project" => project, "version" => version, "filename" => _filename}) do
    case Repository.get_release_metadata(project, version) do
      nil -> send_resp(conn, 404, "metadata not found")
      metadata -> conn |> put_resp_content_type("text/plain") |> send_resp(200, metadata)
    end
  end

  # ----------------- Upload endpoints -----------------
  def legacy_upload(conn, params) do
    # enforce auth
    case require_auth!(conn) do
      {:ok, _conn} ->
        # use Repository.create_upload/2 to save uploaded file and metadata
        case Repository.handle_legacy_upload(params) do
          {:ok, record} -> conn |> put_resp_content_type("application/json") |> send_resp(200, Jason.encode!(%{ok: true, id: record.id}))
          {:error, reason} -> conn |> put_resp_content_type("application/json") |> send_resp(400, Jason.encode!(%{error: inspect(reason)}))
        end
      _ -> conn
    end
  end

  def xmlrpc(conn, _params) do
    case require_auth!(conn) do
      {:ok, _conn} ->
        {:ok, body, _} = read_body(conn)
        method = parse_xmlrpc_method(body)

        response_xml =
          case method do
            {:ok, "package_releases"} -> Repository.xmlrpc_package_releases()
            {:ok, "release_urls"} -> Repository.xmlrpc_release_urls()
            _ -> xmlrpc_response(nil)
          end

        conn |> put_resp_content_type("text/xml") |> send_resp(200, response_xml)
      _ -> conn
    end
  end

  # ----------------- small xmlrpc helpers -----------------
  defp parse_xmlrpc_method(body) when is_binary(body) do
    case Regex.run(~r/<methodName>\s*([^<]+)\s*<\/methodName>/, body) do
      [_, m] -> {:ok, String.trim(m)}
      _ -> :error
    end
  end

  defp xmlrpc_response(nil) do
    """
    <?xml version="1.0"?>
    <methodResponse>
      <params>
        <param><value><nil/></value></param>
      </params>
    </methodResponse>
    """
  end

  defp xmlrpc_response(list) when is_list(list) do
    items = Enum.map(list, fn v -> "<value><string>#{v}</string></value>" end) |> Enum.join("\n")
    """
    <?xml version="1.0"?>
    <methodResponse>
      <params>
        <param>
          <value>
            <array>
              <data>
                #{items}
              </data>
            </array>
          </value>
        </param>
      </params>
    </methodResponse>
    """
  end
end

# --------------------------------------------------
# File: lib/bindepot/repository/package.ex (Ecto schemas)
defmodule Bindepot.Repository.Package do
  use Ecto.Schema
  import Ecto.Changeset

  schema "packages" do
    field :name, :string
    has_many :releases, Bindepot.Repository.Release
    timestamps()
  end

  def changeset(pkg, attrs) do
    pkg
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end

# File: lib/bindepot/repository/release.ex
defmodule Bindepot.Repository.Release do
  use Ecto.Schema
  import Ecto.Changeset

  schema "releases" do
    field :version, :string
    field :metadata, :map
    belongs_to :package, Bindepot.Repository.Package
    has_many :dist_files, Bindepot.Repository.DistFile
    timestamps()
  end

  def changeset(release, attrs) do
    release
    |> cast(attrs, [:version, :metadata, :package_id])
    |> validate_required([:version, :package_id])
  end
end

# File: lib/bindepot/repository/dist_file.ex
defmodule Bindepot.Repository.DistFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dist_files" do
    field :filename, :string
    field :url, :string
    field :path, :string
    field :hashes, :map
    belongs_to :release, Bindepot.Repository.Release
    timestamps()
  end

  def changeset(df, attrs) do
    df
    |> cast(attrs, [:filename, :url, :path, :hashes, :release_id])
    |> validate_required([:filename, :release_id])
  end
end

# --------------------------------------------------
# File: lib/bindepot/repository.ex (context)
defmodule Bindepot.Repository do
  @moduledoc "Context for package metadata and distributions (persistence/backing for controller)."
  import Ecto.Query, warn: false
  alias Bindepot.Repo
  alias Bindepot.Repository.{Package, Release, DistFile}

  # indexing / PEP 691 builders
  def list_package_names do
    Repo.all(from p in Package, select: p.name)
  end

  def build_index_json do
    %{
      "meta" => %{"_generated_by" => "bindepot", "_last-serial" => 0},
      "projects" => Enum.map(list_package_names(), &%{"name" => &1})
    }
  end

  def get_project_with_releases(name) do
    case Repo.get_by(Package, name: name) do
      nil -> nil
      pkg ->
        releases = Repo.all(from r in Release, where: r.package_id == ^pkg.id, preload: [:dist_files])
        %{package: pkg, releases: releases}
    end
  end

  def build_project_json(name) do
    case get_project_with_releases(name) do
      nil -> nil
      %{package: pkg, releases: releases} ->
        %{
          "meta" => %{"name" => pkg.name},
          "files" =>
            releases
            |> Enum.flat_map(fn r ->
              Enum.map(r.dist_files, fn f ->
                %{
                  "filename" => f.filename,
                  "url" => f.url || "/pypi/packages/#{pkg.name}/#{r.version}/#{f.filename}",
                  "hashes" => f.hashes || %{},
                  "requires-python" => Map.get(r.metadata || %{}, "Requires-Python"),
                  "dist-info-metadata" => (f.url || "/pypi/packages/#{pkg.name}/#{r.version}/#{f.filename}") <> "/METADATA"
                }
              end)
            end)
        }
    end
  end

  def get_distribution_file(project, version, filename) do
    query = from f in DistFile,
      join: r in Release, on: r.id == f.release_id,
      join: p in Package, on: p.id == r.package_id,
      where: p.name == ^project and r.version == ^version and f.filename == ^filename,
      select: f

    Repo.one(query)
  end

  def get_release_metadata(project, version) do
    query = from r in Release,
      join: p in Package, on: p.id == r.package_id,
      where: p.name == ^project and r.version == ^version,
      select: r.metadata

    case Repo.one(query) do
      nil -> nil
      metadata when is_map(metadata) ->
        # produce textual METADATA from map (simple implementation)
        metadata
        |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
        |> Enum.join("\n")
    end
  end

  # Basic upload handling: expects params from multipart/form-data as Plug provides them
  def handle_legacy_upload(params) do
    name = Map.get(params, "name")
    version = Map.get(params, "version")
    upload = Map.get(params, "content")

    Repo.transaction(fn ->
      pkg = Repo.get_by(Package, name: name) || %Package{} |> Package.changeset(%{name: name}) |> Repo.insert!()
      rel = %Release{} |> Release.changeset(%{version: version, package_id: pkg.id, metadata: %{}}) |> Repo.insert!()

      # handle uploaded file if present
      dist =
        case upload do
          %Plug.Upload{filename: fname, path: path} ->
            %DistFile{}
            |> DistFile.changeset(%{filename: fname, path: path, release_id: rel.id})
            |> Repo.insert!()
          _ ->
            %DistFile{}
            |> DistFile.changeset(%{filename: Map.get(params, "filename") || "unknown", url: Map.get(params, "url"), release_id: rel.id})
            |> Repo.insert!()
        end

      {:ok, dist}
    end)
  end

  # helpers used by xmlrpc mock
  def xmlrpc_package_releases do
    # returns small xmlrpc response body
    """
    <?xml version="1.0"?>
    <methodResponse>
      <params>
        <param>
          <value>
            <array>
              <data>
                <value><string>1.2.0</string></value>
                <value><string>1.1.0</string></value>
              </data>
            </array>
          </value>
        </param>
      </params>
    </methodResponse>
    """
  end

  def xmlrpc_release_urls do
    """
    <?xml version="1.0"?>
    <methodResponse>
      <params>
        <param>
          <value>
            <array>
              <data>
                <value>
                  <struct>
                    <member><name>url</name><value><string>https://example.org/files/examplepkg-1.2.0-py3-none-any.whl</string></value></member>
                    <member><name>filename</name><value><string>examplepkg-1.2.0-py3-none-any.whl</string></value></member>
                    <member><name>md5_digest</name><value><string>d41d8cd98f00b204e9800998ecf8427e</string></value></member>
                  </struct>
                </value>
              </data>
            </array>
          </value>
        </param>
      </params>
    </methodResponse>
    """
  end
end

# --------------------------------------------------
# Migration files (Ecto)
# priv/repo/migrations/20250924000000_create_packages_and_releases.exs

defmodule Bindepot.Repo.Migrations.CreatePackagesAndReleases do
  use Ecto.Migration

  def change do
    create table(:packages) do
      add :name, :string, null: false
      timestamps()
    end

    create unique_index(:packages, [:name])

    create table(:releases) do
      add :package_id, references(:packages, on_delete: :delete_all), null: false
      add :version, :string, null: false
      add :metadata, :map
      timestamps()
    end

    create index(:releases, [:package_id])

    create table(:dist_files) do
      add :release_id, references(:releases, on_delete: :delete_all), null: false
      add :filename, :string, null: false
      add :url, :string
      add :path, :string
      add :hashes, :map
      timestamps()
    end

    create index(:dist_files, [:release_id])
  end
end

# --------------------------------------------------
# Tests: test/bindepot/repository/pypi_controller_test.exs

defmodule Bindepot.Repository.PypiControllerTest do
  use BindepotWeb.ConnCase, async: true
  alias Bindepot.Repo
  alias Bindepot.Repository

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Bindepot.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Bindepot.Repo, {:shared, self()})

    # Insert a package, release and distfile fixture
    pkg = %Bindepot.Repository.Package{} |> Bindepot.Repository.Package.changeset(%{name: "examplepkg"}) |> Repo.insert!()
    rel = %Bindepot.Repository.Release{} |> Bindepot.Repository.Release.changeset(%{version: "1.2.0", package_id: pkg.id, metadata: %{"Summary" => "A test pkg"}}) |> Repo.insert!()
    %Bindepot.Repository.DistFile{} |> Bindepot.Repository.DistFile.changeset(%{filename: "examplepkg-1.2.0-py3-none-any.whl", url: "/pypi/packages/examplepkg/1.2.0/examplepkg-1.2.0-py3-none-any.whl", release_id: rel.id}) |> Repo.insert!()

    {:ok, pkg: pkg, rel: rel}
  end

  test "GET /pypi/simple/ returns HTML list", %{conn: conn} do
    conn = get(conn, "/pypi/simple/")
    assert html_response(conn, 200) =~ "examplepkg"
  end

  test "GET /pypi/simple/?format=json returns PEP691 JSON", %{conn: conn} do
    conn = get(conn, "/pypi/simple/?format=json")
    assert get_resp_header(conn, "content-type") |> List.first() =~ "application/vnd.pypi.simple.v1+json"
    assert json_response(conn, 200)["projects"] |> Enum.any?(fn p -> p["name"] == "examplepkg" end)
  end

  test "per-project JSON returns files", %{conn: conn} do
    conn = get(conn, "/pypi/simple/examplepkg/?format=json")
    assert json_response(conn, 200)["meta"]["name"] == "examplepkg"
    assert json_response(conn, 200)["files"] |> Enum.any?(fn f -> f["filename"] =~ "examplepkg-1.2.0" end)
  end

  test "serve metadata returns METADATA text", %{conn: conn} do
    conn = get(conn, "/pypi/packages/examplepkg/1.2.0/examplepkg-1.2.0-py3-none-any.whl/METADATA")
    assert response(conn, 200) =~ "Summary: A test pkg"
  end

  test "upload requires auth and accepts form upload", %{conn: conn} do
    # without auth
    conn = post(conn, "/pypi/legacy/", %{"name" => "u1", "version" => "0.1.0"})
    assert conn.status == 401

    # with mock token (configured in test.exs to include "mock-token")
    conn = conn |> put_req_header("authorization", "Bearer mock-token") |> post("/pypi/legacy/", %{"name" => "u1", "version" => "0.1.0"})
    assert json_response(conn, 200)["ok"] == true
  end
end

# --------------------------------------------------
# Curl examples (README-style snippets)

# 1) Fetch HTML simple index (PEP 503)
# curl -v http://localhost:4000/pypi/simple/

# 2) Fetch JSON simple index (PEP 691)
# curl -H "Accept: application/vnd.pypi.simple.v1+json" http://localhost:4000/pypi/simple/

# 3) Fetch per-project JSON
# curl -H "Accept: application/vnd.pypi.simple.v1+json" http://localhost:4000/pypi/simple/examplepkg/

# 4) Twine upload using token (HTTP Basic __token__ or Bearer):
# Using Basic (two approaches):
# TWINE_USERNAME="__token__" TWINE_PASSWORD="mock-token" twine upload --repository-url http://localhost:4000/pypi/legacy/ dist/*
# or with curl (simplified):
# curl -i -u __token__:mock-token -F "content=@./dist/examplepkg-0.1.0.tar.gz" -F "name=examplepkg" -F "version=0.1.0" http://localhost:4000/pypi/legacy/

# 5) XML-RPC query
# curl -X POST -H "Authorization: Bearer mock-token" -H "Content-Type: text/xml" --data '<methodCall><methodName>package_releases</methodName></methodCall>' http://localhost:4000/pypi

# --------------------------------------------------
# Notes / Integration steps
# 1. Add the migration file to priv/repo/migrations and run `mix ecto.migrate`.
# 2. Ensure Repo is configured (Bindepot.Repo) and included in application supervision tree.
# 3. Add the controller router snippet into lib/bindepot_web/router.ex and `mix phx.server`.
# 4. Endpoint parsers should include :urlencoded, :multipart and JSON parser in endpoint/router pipeline.
#    Example in endpoint or router: plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Jason
# 5. Configure allowed tokens in config/test.exs and config/dev.exs:
#    config :bindepot, Bindepot.Repository.Controllers.PypiController, api_tokens: ["mock-token"]
# 6. Run tests: MIX_ENV=test mix ecto.create && mix ecto.migrate && mix test

# End of textdoc
