defmodule EWalletAPI.V1.AuthController do
  use EWalletAPI, :controller
  alias EWallet.UserPolicy
  alias EWalletAPI.V1.Plug.ClientAuthPlug
  alias EWalletDB.{Account, AuthToken, User}

  @doc """
  Signs up a new user.

  This function is used when the eWallet is setup as a standalone solution,
  allowing users to sign up without an integration with the provider's server.
  """
  @spec signup(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def signup(conn, _attrs) do
    with :ok <- permit(:create, conn.assigns, nil),
         {:ok, user} <- User.insert(attrs) do
      render(conn, :user, %{user: user})
    else
      {:error, %Changeset{} = changeset} ->
        handle_error(conn, :invalid_parameter, changeset)

      {:error, code} ->
        handle_error(conn, code)
    end
  end

  @doc """
  Logins the user.

  This function is used when the eWallet is setup as a standalone solution,
  allowing users to log in without an integration with the provider's server.
  """
  def login(conn, attrs) do
    with email <- attrs["email"] || :missing_email,
         password <- attrs["password"] || :missing_password,
         %{assigns: %{authenticated: true}}} <- UserAuth.authenticate(email, password),
         {:ok, auth_token} <- AuthToken.generate(conn.assigns.auth_user, :ewallet_api) do
      render(conn, :auth_token, %{auth_token: auth_token})
    else
      :missing_email ->
        handle_error(conn, :invalid_parameter, "`email` is required")

      :missing_password ->
        handle_error(conn, :invalid_parameter, "`password` is required")

      _ ->
        handle_error(conn, :invalid_login_credentials)
    end
  end

  @doc """
  Invalidates the authentication token used in this request.

  Note that this function can logout the user sessions generated by both
  the Admin API and the eWallet API.
  """
  def logout(conn, _attrs) do
    conn
    |> ClientAuthPlug.expire_token()
    |> render(:empty_response, %{})
  end

  @spec permit(:create, map(), %User{} | nil) :: :ok | {:error, any()}
  defp permit(action, params, user) do
    Bodyguard.permit(UserPolicy, action, params, user)
  end
end
