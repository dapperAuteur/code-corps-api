defmodule CodeCorpsWeb.PasswordResetController do
  @moduledoc false
  use CodeCorpsWeb, :controller

  alias CodeCorps.{User, AuthToken}
  alias Ecto.Changeset

  @doc"""
  Requires a `token`, `password`, and `password_confirmation` and checks:

  1. The token exists in an `AuthToken` record, verified with
  `Phoenix.Token.verify`

  2. The `password` and `password_confirmation` match, and the auth token
  exists:

    - If yes, a `200` response will return the email.
    - If no, a `422` response will return the error.
  """
  def reset_password(conn, %{"token" => reset_token, "password" => _password, "password_confirmation" => _password_confirmation} = params) do
    with %AuthToken{user: user} = auth_token <- AuthToken |> Repo.get_by(%{ value: reset_token }) |> Repo.preload(:user),
         {:ok, _} <- Phoenix.Token.verify(conn, "user", reset_token, max_age: Application.get_env(:code_corps, :password_reset_timeout)),
         {:ok, updated_user} <- user |> User.reset_password_changeset(params) |> Repo.update,
         {:ok, _auth_token} <- auth_token |> Repo.delete,
         {:ok, auth_token, _claims} = updated_user |> Guardian.encode_and_sign(:token)
    do
      conn
      |> Plug.Conn.assign(:current_user, updated_user)
      |> put_status(:created)
      |> render("show.json", token: auth_token, user_id: updated_user.id, email: updated_user.email)
    else
      {:error, %Changeset{} = changeset} -> conn |> put_status(422) |> render(CodeCorpsWeb.ErrorView, :errors, data: changeset)
      {:error, _} -> conn |> put_status(:not_found) |> render(CodeCorpsWeb.ErrorView, "404.json")
      nil -> conn |> put_status(:not_found) |> render(CodeCorpsWeb.ErrorView, "404.json")
    end
  end

end
