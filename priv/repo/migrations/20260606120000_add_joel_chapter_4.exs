defmodule BibleReader.Repo.Migrations.AddJoelChapter4 do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO chapters (book_id, chapter_number)
    SELECT b.id, 4
    FROM books b
    WHERE b.code = 'JOE'
      AND NOT EXISTS (
        SELECT 1
        FROM chapters c
        WHERE c.book_id = b.id AND c.chapter_number = 4
      )
    """
  end

  def down do
    execute """
    DELETE FROM chapters
    WHERE chapter_number = 4
      AND book_id IN (SELECT id FROM books WHERE code = 'JOE')
    """
  end
end
