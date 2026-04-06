defmodule BibleReader.Repo do
  use Ecto.Repo,
    otp_app: :biblereader,
    adapter: Ecto.Adapters.Postgres
end
