defmodule Bindepot.Pypi.Repository do
  @moduledoc "Context for package metadata and distributions (persistence/backing for controller)."
  import Ecto.Query, warn: false
  alias Bindepot.Repo
  alias Bindepot.Pypi.{Package, Release, DistFile}

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
