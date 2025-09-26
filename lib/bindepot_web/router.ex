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

  scope "/", BindepotWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/bindepot", BindepotWeb do
    pipe_through :api

    scope "/api", Api do
      put "/repositories/:repository", RepositoryController, :create_repository
      delete "/repositories/:repository", RepositoryController, :delete_repository

      scope "/pypi" do
        get "/:repository/simple/", PypiController, :simple_index
        get "/:repository/simple/:name/", PypiController, :project_index

        get "/:repository/packages/:project/:version/:filename", PypiController, :serve_package
        get "/:repository/packages/:project/:version/:filename/METADATA", PypiController, :serve_metadata

        post "/:repository/legacy/", PypiController, :legacy_upload
        # post "/:repository/pypi", PypiController, :xmlrpc
      end
    end
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
