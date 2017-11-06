defmodule CodeCorps.GitHub.API.Installation do
  @moduledoc """
  Functions for performing installation actions on the GitHub API.
  """

  alias CodeCorps.{
    GitHub,
    GithubAppInstallation,
    Repo
  }

  alias Ecto.Changeset

  @doc """
  List repositories that are accessible to the authenticated installation.

  All pages of records are retrieved.

  https://developer.github.com/v3/apps/installations/#list-repositories
  """
  @spec repositories(GithubAppInstallation.t) :: {:ok, list(map)} | {:error, GitHub.api_error_struct}
  def repositories(%GithubAppInstallation{} = installation) do
    with {:ok, access_token} <- installation |> get_access_token(),
         {:ok, responses} <- fetch_repositories(access_token),
         repositories <- extract_repositories(responses) do
      {:ok, repositories}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp fetch_repositories(access_token) do
    "installation/repositories"
    |> GitHub.get_all(%{}, [access_token: access_token, params: [per_page: 100]])
    |> (&{:ok, &1}).()
  end

  defp extract_repositories(responses) do
    responses
    |> Enum.reduce([], &merge_repositories/2)
  end

  defp merge_repositories(response, acc) do
    acc |> Enum.concat(response |> Map.get("repositories"))
  end

  @doc """
  Get the access token for the installation.

  Returns either the current access token stored in the database because
  it has not yet expired, or makes a request to the GitHub API for a new
  access token using the GitHub App's JWT.

  https://developer.github.com/apps/building-integrations/setting-up-and-registering-github-apps/about-authentication-options-for-github-apps/#authenticating-as-an-installation
  """
  @spec get_access_token(GithubAppInstallation.t) :: {:ok, String.t} | {:error, GitHub.api_error_struct} | {:error, Changeset.t}
  def get_access_token(%GithubAppInstallation{access_token: token, access_token_expires_at: expires_at} = installation) do
    case token_expired?(expires_at) do
      true ->  installation |> refresh_token()
      false -> {:ok, token} # return the existing token
    end
  end

  @doc """
  Refreshes the access token for the installation.

  Makes a request to the GitHub API for a new access token using the GitHub
  App's JWT.

  https://developer.github.com/apps/building-integrations/setting-up-and-registering-github-apps/about-authentication-options-for-github-apps/#authenticating-as-an-installation
  """
  @spec refresh_token(GithubAppInstallation.t) :: {:ok, String.t} | {:error, GitHub.api_error_struct} | {:error, Changeset.t}
  def refresh_token(%GithubAppInstallation{github_id: installation_id} = installation) do
    endpoint = "installations/#{installation_id}/access_tokens"
    with {:ok, %{"token" => token, "expires_at" => expires_at}} <-
           GitHub.integration_request(:post, endpoint, %{}, %{}, []),
         {:ok, %GithubAppInstallation{}} <-
           update_token(installation, token, expires_at)
    do
      {:ok, token}
    else
      {:error, error} -> {:error, error}
    end
  end

  @spec update_token(GithubAppInstallation.t, String.t, String.t) :: {:ok, GithubAppInstallation.t} | {:error, Changeset.t}
  defp update_token(%GithubAppInstallation{} = installation, token, expires_at) do
    installation
    |> GithubAppInstallation.access_token_changeset(%{access_token: token, access_token_expires_at: expires_at})
    |> Repo.update
  end

  @doc false
  @spec token_expired?(String.t | DateTime.t | nil) :: true | false
  def token_expired?(expires_at) when is_binary(expires_at) do
    expires_at
    |> Timex.parse!("{ISO:Extended:Z}")
    |> token_expired?()
  end
  def token_expired?(%DateTime{} = expires_at) do
    Timex.before?(expires_at, Timex.now)
  end
  def token_expired?(nil), do: true
end
