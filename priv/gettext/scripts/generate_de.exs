# Generates de/LC_MESSAGES/default.po and books.po from translation maps.
# Run: mix run priv/gettext/scripts/generate_de.exs

alias BibleReader.Scripture.Catalog

default_translations = %{
  "%{book} %{number}" => "%{book} %{number}",
  "%{book} chapter %{number}" => "%{book} Kapitel %{number}",
  "%{count} chapters in the last %{days} days" =>
    "%{count} Kapitel in den letzten %{days} Tagen",
  "%{count}d" => "%{count}T",
  "%{count}mo" => "%{count}Mon",
  "%{count}y" => "%{count}J",
  "%{read} of %{total} chapters read" => "%{read} von %{total} Kapiteln gelesen",
  "%{read}/%{total} read" => "%{read}/%{total} gelesen",
  "1d" => "1T",
  "A link to confirm your email change has been sent to the new address." =>
    "Ein Link zur Bestätigung Ihrer E-Mail-Änderung wurde an die neue Adresse gesendet.",
  "Account Settings" => "Kontoeinstellungen",
  "Actions" => "Aktionen",
  "All" => "Alle",
  "Already registered?" => "Bereits registriert?",
  "At this pace, first time through every chapter in scope: %{eta}" =>
    "In diesem Tempo dauert es bis zum ersten Mal durch jedes Kapitel im Umfang: %{eta}",
  "At this pace, full coverage would take a very long time." =>
    "In diesem Tempo würde eine vollständige Abdeckung sehr lange dauern.",
  "At this pace, touching every chapter in scope at least once: about %{days} days." =>
    "In diesem Tempo, jedes Kapitel im Umfang mindestens einmal zu lesen: etwa %{days} Tage.",
  "Attempting to reconnect" => "Verbindung wird wiederhergestellt",
  "Back to home" => "Zurück zur Startseite",
  "Bible Reader" => "Bibel Leser",
  "Book not found." => "Buch nicht gefunden.",
  "Books" => "Bücher",
  "Change Email" => "E-Mail ändern",
  "Change Password" => "Passwort ändern",
  "Changing..." => "Wird geändert…",
  "Chapter marked as read." => "Kapitel als gelesen markiert.",
  "Chapter not found." => "Kapitel nicht gefunden.",
  "Chapters" => "Kapitel",
  "Chapters not yet read at least once: %{count}" =>
    "Noch nicht mindestens einmal gelesene Kapitel: %{count}",
  "Confirm Account" => "Konto bestätigen",
  "Confirm my account" => "Mein Konto bestätigen",
  "Confirm new password" => "Neues Passwort bestätigen",
  "Confirmation instructions" => "Bestätigungsanleitung",
  "Confirming..." => "Wird bestätigt…",
  "Continue %{book} %{chapter}" => "Weiter %{book} %{chapter}",
  "Continue reading" => "Weiterlesen",
  "Could not log read." => "Lesen konnte nicht protokolliert werden.",
  "Could not save note." => "Notiz konnte nicht gespeichert werden.",
  "Create an account" => "Konto erstellen",
  "Creating account..." => "Konto wird erstellt…",
  "Current pace" => "Aktuelles Tempo",
  "Current password" => "Aktuelles Passwort",
  "Distinct chapters read: %{read} / %{total}" =>
    "Unterschiedliche gelesene Kapitel: %{read} / %{total}",
  "Don't have an account?" => "Noch kein Konto?",
  "Email" => "E-Mail",
  "Email change link is invalid or it has expired." =>
    "Der E-Mail-Änderungslink ist ungültig oder abgelaufen.",
  "Email changed successfully." => "E-Mail erfolgreich geändert.",
  "English" => "Englisch",
  "Error!" => "Fehler!",
  "Forgot your password?" => "Passwort vergessen?",
  "Full Bible text is not available in this version yet. Run mix scripture.import deuelbbk to import the Elberfelder translation, or use your own Bible for reading; use this page to log progress and keep notes." =>
    "Der vollständige Bibeltext ist in dieser Version noch nicht verfügbar. Führen Sie mix scripture.import deuelbbk aus, um die Elberfelder-Übersetzung zu importieren, oder nutzen Sie Ihre eigene Bibel zum Lesen; auf dieser Seite können Sie Fortschritt protokollieren und Notizen führen.",
  "German" => "Deutsch",
  "Hang in there while we get back on track" =>
    "Einen Moment — wir sind gleich wieder für Sie da",
  "Hi %{email}," => "Hallo %{email},",
  "Hide stats" => "Statistik ausblenden",
  "Home" => "Start",
  "IANA time zone" => "IANA-Zeitzone",
  "If you didn't create an account with us, please ignore this." =>
    "Wenn Sie kein Konto bei uns erstellt haben, ignorieren Sie diese Nachricht.",
  "If you didn't request this change, please ignore this." =>
    "Wenn Sie diese Änderung nicht angefordert haben, ignorieren Sie diese Nachricht.",
  "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly." =>
    "Wenn Ihre E-Mail in unserem System ist und noch nicht bestätigt wurde, erhalten Sie in Kürze eine E-Mail mit Anweisungen.",
  "If your email is in our system, you will receive instructions to reset your password shortly." =>
    "Wenn Ihre E-Mail in unserem System ist, erhalten Sie in Kürze Anweisungen zum Zurücksetzen Ihres Passworts.",
  "Keep me logged in" => "Angemeldet bleiben",
  "Language" => "Sprache",
  "Last read: %{book} %{chapter} · %{age}" =>
    "Zuletzt gelesen: %{book} %{chapter} · %{age}",
  "Last read: %{label} · Read count: %{count}" =>
    "Zuletzt gelesen: %{label} · Anzahl Lesungen: %{count}",
  "Last read: chapter %{number}" => "Zuletzt gelesen: Kapitel %{number}",
  "Legend:" => "Legende:",
  "Log in" => "Anmelden",
  "Log in to account" => "Bei Ihrem Konto anmelden",
  "Log out" => "Abmelden",
  "Log your first chapter from any book below to see a continue reading suggestion." =>
    "Protokollieren Sie Ihr erstes Kapitel aus einem der Bücher unten, um einen Weiterlesen-Vorschlag zu sehen.",
  "Logging in..." => "Anmeldung läuft…",
  "Manage your account email address and password settings" =>
    "E-Mail-Adresse und Passwort Ihres Kontos verwalten",
  "Mark as read" => "Als gelesen markieren",
  "More stats" => "Mehr Statistik",
  "New password" => "Neues Passwort",
  "No confirmation instructions received?" =>
    "Keine Bestätigungsanleitung erhalten?",
  "No reads logged for this chapter yet." =>
    "Für dieses Kapitel sind noch keine Lesungen protokolliert.",
  "Not read yet" => "Noch nicht gelesen",
  "Note saved." => "Notiz gespeichert.",
  "Notes" => "Notizen",
  "Old Testament" => "Altes Testament",
  "New Testament" => "Neues Testament",
  "Oops, something went wrong! Please check the errors below." =>
    "Etwas ist schiefgelaufen! Bitte prüfen Sie die Fehler unten.",
  "Open chapter" => "Kapitel öffnen",
  "Password" => "Passwort",
  "Password reset successfully." => "Passwort erfolgreich zurückgesetzt.",
  "Privacy" => "Datenschutz",
  "Progress" => "Fortschritt",
  "Reading history" => "Leseverlauf",
  "Reading preferences" => "Leseeinstellungen",
  "Reading preferences updated." => "Leseeinstellungen aktualisiert.",
  "Recently read" => "Kürzlich gelesen",
  "Register" => "Registrieren",
  "Register for an account" => "Konto registrieren",
  "Reset Password" => "Passwort zurücksetzen",
  "Reset password instructions" => "Anleitung zum Zurücksetzen des Passworts",
  "Reset password link is invalid or it has expired." =>
    "Der Link zum Zurücksetzen des Passworts ist ungültig oder abgelaufen.",
  "Resetting..." => "Wird zurückgesetzt…",
  "Resend confirmation instructions" => "Bestätigungsanleitung erneut senden",
  "Save note" => "Notiz speichern",
  "Save reading preferences" => "Leseeinstellungen speichern",
  "Saved" => "Gespeichert",
  "Saving..." => "Wird gespeichert…",
  "Scripture text" => "Bibeltext",
  "Send password reset instructions" => "Anleitung zum Passwort-Reset senden",
  "Sending..." => "Wird gesendet…",
  "Settings" => "Einstellungen",
  "Show apocryphal books" => "Apokryphe Bücher anzeigen",
  "Sign up" => "Registrieren",
  "Something went wrong!" => "Etwas ist schiefgelaufen!",
  "Start your reading journey" => "Starten Sie Ihre Lese-Reise",
  "Success!" => "Erfolg!",
  "Today" => "Heute",
  "Try a small goal: 3 chapters per week." =>
    "Probieren Sie ein kleines Ziel: 3 Kapitel pro Woche.",
  "Update email instructions" => "Anleitung zur E-Mail-Aktualisierung",
  "User confirmation link is invalid or it has expired." =>
    "Der Bestätigungslink ist ungültig oder abgelaufen.",
  "User confirmed successfully." => "Benutzer erfolgreich bestätigt.",
  "We'll send a new confirmation link to your inbox" =>
    "Wir senden einen neuen Bestätigungslink an Ihr Postfach",
  "We'll send a password reset link to your inbox" =>
    "Wir senden einen Link zum Zurücksetzen des Passworts an Ihr Postfach",
  "We can't find the internet" => "Keine Internetverbindung",
  "Write a note for this chapter..." => "Notiz für dieses Kapitel schreiben…",
  "You can change your email by visiting the URL below:" =>
    "Sie können Ihre E-Mail über die URL unten ändern:",
  "You can confirm your account by visiting the URL below:" =>
    "Sie können Ihr Konto über die URL unten bestätigen:",
  "You can reset your password by visiting the URL below:" =>
    "Sie können Ihr Passwort über die URL unten zurücksetzen:",
  "You must log in to access this page." =>
    "Sie müssen sich anmelden, um diese Seite aufzurufen.",
  "a very long time" => "sehr lange",
  "about %{days} days" => "etwa %{days} Tage",
  "chapters read" => "Kapitel gelesen",
  "close" => "schließen",
  "empty = unread · strong green = today · soft green = < 7 days · teal = < 30 days · pale = older" =>
    "leer = ungelesen · kräftig grün = heute · hellgrün = < 7 Tage · blaugrün = < 30 Tage · blass = älter",
  "for an account now." => "für ein Konto.",
  "include apocryphal books, timezone, language, and account." =>
    "Apokryphe Bücher, Zeitzone, Sprache und Konto.",
  "notes" => "Notizen",
  "this week" => "diese Woche",
  "today" => "heute",
  "yesterday" => "gestern",
  "Bible Reader stores the account information you provide (such as email) and your reading activity (which chapters you log, and when). We use essential session cookies so you can stay signed in securely; we do not use third-party analytics cookies in this application by default." =>
    "Bible Reader speichert die von Ihnen angegebenen Kontodaten (z. B. E-Mail) und Ihre Leseaktivität (welche Kapitel Sie wann protokollieren). Wir verwenden notwendige Session-Cookies, damit Sie sicher angemeldet bleiben können; standardmäßig setzen wir keine Analyse-Cookies von Drittanbietern.",
  "You may update your time zone, language, and other preferences in Settings. For data export or deletion requests, contact the operator of this deployment; retention and subprocessors depend on where the app is hosted." =>
    "Zeitzone, Sprache und weitere Einstellungen können Sie unter Einstellungen anpassen. Für Datenexport oder Löschung wenden Sie sich an den Betreiber dieser Installation; Aufbewahrung und Unterauftragsverarbeiter hängen vom Hosting ab."
}

german_books = %{
  "GEN" => "1. Mose",
  "EXO" => "2. Mose",
  "LEV" => "3. Mose",
  "NUM" => "4. Mose",
  "DEU" => "5. Mose",
  "JOS" => "Josua",
  "JDG" => "Richter",
  "RUT" => "Rut",
  "1SA" => "1. Samuel",
  "2SA" => "2. Samuel",
  "1KI" => "1. Könige",
  "2KI" => "2. Könige",
  "1CH" => "1. Chronik",
  "2CH" => "2. Chronik",
  "EZR" => "Esra",
  "NEH" => "Nehemia",
  "EST" => "Esther",
  "JOB" => "Hiob",
  "PSA" => "Psalmen",
  "PRO" => "Sprüche",
  "ECC" => "Prediger",
  "SNG" => "Hohelied",
  "ISA" => "Jesaja",
  "JER" => "Jeremia",
  "LAM" => "Klagelieder",
  "EZK" => "Hesekiel",
  "DAN" => "Daniel",
  "HOS" => "Hosea",
  "JOE" => "Joel",
  "AMO" => "Amos",
  "OBA" => "Obadja",
  "JON" => "Jona",
  "MIC" => "Micha",
  "NAM" => "Nahum",
  "HAB" => "Habakuk",
  "ZEP" => "Zephanja",
  "HAG" => "Haggai",
  "ZEC" => "Sacharja",
  "MAL" => "Maleachi",
  "TOB" => "Tobit",
  "JDT" => "Judit",
  "WIS" => "Weisheit Salomos",
  "SIR" => "Jesus Sirach",
  "BAR" => "Baruch",
  "1MA" => "1. Makkabäer",
  "2MA" => "2. Makkabäer",
  "MAT" => "Matthäus",
  "MRK" => "Markus",
  "LUK" => "Lukas",
  "JHN" => "Johannes",
  "ACT" => "Apostelgeschichte",
  "ROM" => "Römer",
  "1CO" => "1. Korinther",
  "2CO" => "2. Korinther",
  "GAL" => "Galater",
  "EPH" => "Epheser",
  "PHP" => "Philipper",
  "COL" => "Kolosser",
  "1TH" => "1. Thessalonicher",
  "2TH" => "2. Thessalonicher",
  "1TI" => "1. Timotheus",
  "2TI" => "2. Timotheus",
  "TIT" => "Titus",
  "PHM" => "Philemon",
  "HEB" => "Hebräer",
  "JAS" => "Jakobus",
  "1PE" => "1. Petrus",
  "2PE" => "2. Petrus",
  "1JN" => "1. Johannes",
  "2JN" => "2. Johannes",
  "3JN" => "3. Johannes",
  "JUD" => "Judas",
  "REV" => "Offenbarung"
}

english_books = Catalog.books() |> Map.new(fn b -> {b.code, b.name} end)

defmodule PoWriter do
  def write_default_po(path, translations) do
    en_path = "priv/gettext/en/LC_MESSAGES/default.po"
    content = File.read!(en_path)

    de_content =
      content
      |> String.replace("\"Language: en\\n\"", "\"Language: de\\n\"")
      |> replace_msgstrs(translations)

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, de_content)
  end

  defp replace_msgstrs(content, translations) do
    Regex.replace(
      ~r/msgid "((?:\\.|[^"])*)"\nmsgstr ""/,
      content,
      fn _, msgid ->
        unescaped = unescape_po(msgid)
        msgstr = Map.get(translations, unescaped, unescaped)
        "msgid \"#{msgid}\"\nmsgstr \"#{escape_po(msgstr)}\""
      end
    )
  end

  defp unescape_po(s), do: String.replace(s, ~S(\"), "\"")
  defp escape_po(s), do: String.replace(s, "\"", ~S(\"))

  def write_books_po(path, translations, language) do
    header = """
    msgid ""
    msgstr ""
    "Language: #{language}\\n"
    "Plural-Forms: nplurals=2; plural=(n != 1);\\n"

    """

    entries =
      for {code, name} <- Enum.sort(translations) do
        """
        msgid "#{code}"
        msgstr "#{escape_po(name)}"
        """
      end

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, header <> Enum.join(entries, "\n"))
  end
end

PoWriter.write_default_po("priv/gettext/de/LC_MESSAGES/default.po", default_translations)
PoWriter.write_books_po("priv/gettext/en/LC_MESSAGES/books.po", english_books, "en")
PoWriter.write_books_po("priv/gettext/de/LC_MESSAGES/books.po", german_books, "de")

IO.puts("Generated de/default.po and books.po files")
