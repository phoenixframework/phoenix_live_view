defmodule Phoenix.LiveView.Session do
  @moduledoc false
  alias Phoenix.LiveView.{Session, Route, Static}

  defstruct id: nil,
            view: nil,
            root_view: nil,
            parent_pid: nil,
            root_pid: nil,
            session: %{},
            redirected?: false,
            router: nil,
            flash: nil,
            live_session_name: nil,
            live_session_vsn: nil,
            assign_new: []

  def main?(%Session{} = session), do: !is_nil(session.router) and !session.parent_pid

  def authorize_root_redirect(%Session{} = session, %Route{} = route) do
    %Session{live_session_name: session_name, live_session_vsn: session_vsn} = session

    cond do
      route.live_session.name == session_name and route.live_session.vsn == session_vsn ->
        {:ok, replace_root(session, route.view, self())}

      true ->
        {:error, :unauthorized}
    end
  end

  defp replace_root(%Session{} = session, new_root_view, root_pid) when is_pid(root_pid) do
    %Session{
      session
      | view: new_root_view,
        root_view: new_root_view,
        root_pid: root_pid,
        assign_new: [],
        redirected?: true
    }
  end

  @doc """
  Verifies the session token.

  Returns the decoded map of session data or an error.

  ## Examples

      iex> verify_session(AppWeb.Endpoint, "topic", encoded_token, static_token)
      {:ok, %Session{} = decoded_session}

      iex> verify_session(AppWeb.Endpoint, "topic", "bad token", "bac static")
      {:error, :invalid}

      iex> verify_session(AppWeb.Endpoint, "topic", "expired", "expired static")
      {:error, :expired}
  """
  def verify_session(endpoint, topic, session_token, static_token) do
    with {:ok, %{id: id} = session} <- Static.verify_token(endpoint, session_token),
         :ok <- verify_topic(topic, id),
         {:ok, static} <- verify_static_token(endpoint, id, static_token) do
      merged_session = Map.merge(session, static)
      {live_session_name, vsn} = merged_session[:live_session] || {nil, nil}

      session = %Session{
        id: id,
        view: merged_session.view,
        root_view: merged_session.root_view,
        parent_pid: merged_session.parent_pid,
        root_pid: merged_session.root_pid,
        session: merged_session.session,
        assign_new: merged_session.assign_new,
        live_session_name: live_session_name,
        live_session_vsn: vsn,
        # optional keys
        router: merged_session[:router],
        flash: merged_session[:flash]
      }

      {:ok, session}
    end
  end

  defp verify_topic("lv:" <> session_id, session_id), do: :ok
  defp verify_topic(_topic, _session_id), do: {:error, :invalid}

  defp verify_static_token(_endpoint, _id, nil), do: {:ok, %{assign_new: []}}

  defp verify_static_token(endpoint, id, token) do
    case Static.verify_token(endpoint, token) do
      {:ok, %{id: ^id}} = ok -> ok
      {:ok, _} -> {:error, :invalid}
      {:error, _} = error -> error
    end
  end
end
