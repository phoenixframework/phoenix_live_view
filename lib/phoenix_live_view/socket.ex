defmodule Phoenix.LiveView.Socket do

  defstruct id: nil,
            view: nil,
            endpoint: nil,
            state: :disconnected,
            signed_params: %{},
            private: %{},
            assigns: %{}

end
