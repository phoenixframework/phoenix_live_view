defmodule Phoenix.LiveViewTest.E2E.Issue4147Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, :render_in_root, fn assigns ->
       ~H"""
       <div id="foobar" phx-hook=".HookOutside"></div>
       <script :type={Phoenix.LiveView.ColocatedHook} name=".HookOutside">
         export default {
           mounted() {
             console.log("HookOutside mounted");
           }
         }
       </script>
       """
     end)}
  end

  def render(assigns) do
    ~H"""
    <h1>Inside</h1>
    """
  end
end
