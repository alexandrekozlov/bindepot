defmodule BindepotWeb.Router do
  use BindepotWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BindepotWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :repo_io do
    plug BindepotWeb.Plugs.GetRepository
  end

  scope "/", BindepotWeb do
    pipe_through :browser

    get "/", PageController, :home

    scope "/ui" do
      live "/", RepositoryLive.Index, :index
      live "/repositories", RepositoryLive.Index, :index
      live "/repositories/new", RepositoryLive.Form, :new
      live "/repositories/:id", RepositoryLive.Show, :show
      live "/repositories/:id/edit", RepositoryLive.Form, :edit
      live "/repositories/:id/upload", RepositoryLive.Upload, :upload
    end
  end

  # Package type spectific API.
  scope "/repositories", BindepotWeb.Api do
    pipe_through :repo_io

    get "/:repo/*path", RepositoryIoController, :handle_request
    post "/:repo/*path", RepositoryIoController, :handle_request
  end

  scope "/api", BindepotWeb.Api do
    pipe_through :api

    get "/repositories", RepositoryController, :list_repositories
    put "/repositories/:name", RepositoryController, :create_repository
    delete "/repositories/:name", RepositoryController, :delete_repository

    get "/trash/repositories", RepositoryController, :list_deleted
    delete "/trash/repositories/:id", RepositoryController, :purge_repository

    scope "/storage" do
      pipe_through :repo_io

      get "/:repo/*path", StorageController, :handle_get
      # TODO: the following deliniation
      #   "/:repo/*path", where path is a directory - return directory info
      #   "/:repo/*path", where path is a file - return file info
      #   "/:repo/*path?list", where path is a directory - list items.
      #                       Also, additional parameters:
      #                           recursive=
      #                           depth=
      #                           includeFolders=

    end

    scope "/assets" do
      pipe_through :repo_io

      get "/:repo/*path", AssetController, :download
      put "/:repo/*path", AssetController, :upload
    end

    # scope "/pypi" do
    #   get "/:repository/simple/", PypiController, :simple_index
    #   get "/:repository/simple/:name/", PypiController, :project_index

    #   get "/:repository/packages/:project/:version/:filename", PypiController, :serve_package
    #   get "/:repository/packages/:project/:version/:filename/METADATA", PypiController, :serve_metadata

    #   post "/:repository/legacy/", PypiController, :legacy_upload
    #   # post "/:repository/pypi", PypiController, :xmlrpc
    # end
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:bindepot, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BindepotWeb.Telemetry
    end
  end
end
