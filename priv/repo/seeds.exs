# Script for populating the database. Run with:
#
#     mix run priv/repo/seeds.exs
#
{:ok, _} = Application.ensure_all_started(:biblereader)

case BibleReader.Scripture.Seed.run() do
  :skipped -> IO.puts("Books already seeded; skipping.")
  :ok -> IO.puts("Seeded scripture catalog.")
end
