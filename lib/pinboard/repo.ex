defmodule Pinboard.Repo do
  use Ecto.Repo,
    otp_app: :pinboard,
    adapter: Ecto.Adapters.Postgres
end
