defmodule Bindepot.Repo do
  use Ecto.Repo,
    otp_app: :bindepot,
    adapter: Ecto.Adapters.Postgres
end
