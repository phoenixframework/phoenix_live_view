defmodule Phoenix.LiveView.Session do
  @moduledoc false
  alias Phoenix.LiveView.{Session, Route}

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
    %Session{root_view: root_view, view: view, live_session_vsn: vsn} = session

    cond do
      route.view == root_view and route.view == view and route.live_session_vsn == vsn ->
        {:ok, %Session{session | redirected?: true}}

      route.live_session_name == session.live_session_name and route.live_session_vsn == vsn ->
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
end
