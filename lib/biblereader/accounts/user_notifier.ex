defmodule BibleReader.Accounts.UserNotifier do
  import Swoosh.Email

  use Gettext, backend: BibleReaderWeb.Gettext

  alias BibleReader.Locale, as: AppLocale
  alias BibleReader.Mailer

  defp mail_from do
    case System.get_env("MAIL_FROM") do
      nil ->
        {"BibleReader", "contact@example.com"}

      from ->
        case Regex.run(~r/^(.+?)\s*<([^>]+)>$/, String.trim(from)) do
          [_, name, email] -> {String.trim(name), String.trim(email)}
          _ -> {"BibleReader", String.trim(from)}
        end
    end
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(mail_from())
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp with_user_locale(%{locale: locale}, fun) when is_function(fun, 0) do
    Gettext.with_locale(BibleReaderWeb.Gettext, AppLocale.normalize(locale), fun)
  end

  defp with_user_locale(_user, fun), do: Gettext.with_locale(BibleReaderWeb.Gettext, "en", fun)

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    with_user_locale(user, fn ->
      deliver(user.email, gettext("Confirmation instructions"), """

      ==============================

      #{gettext("Hi %{email},", email: user.email)}

      #{gettext("You can confirm your account by visiting the URL below:")}

      #{url}

      #{gettext("If you didn't create an account with us, please ignore this.")}

      ==============================
      """)
    end)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    with_user_locale(user, fn ->
      deliver(user.email, gettext("Reset password instructions"), """

      ==============================

      #{gettext("Hi %{email},", email: user.email)}

      #{gettext("You can reset your password by visiting the URL below:")}

      #{url}

      #{gettext("If you didn't request this change, please ignore this.")}

      ==============================
      """)
    end)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    with_user_locale(user, fn ->
      deliver(user.email, gettext("Update email instructions"), """

      ==============================

      #{gettext("Hi %{email},", email: user.email)}

      #{gettext("You can change your email by visiting the URL below:")}

      #{url}

      #{gettext("If you didn't request this change, please ignore this.")}

      ==============================
      """)
    end)
  end
end
