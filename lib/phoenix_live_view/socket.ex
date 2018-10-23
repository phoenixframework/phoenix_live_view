defmodule Phoenix.LiveView.Socket do

  @type assigns :: map
  @type signed_params :: map

  @type t :: %__MODULE__{
    view: Module.t(),
    signed_params: signed_params,
    state: :connected | :disconnected,
    private: map,
    assigns: assigns
  }

  defstruct id: nil,
            view: nil,
            endpoint: nil,
            state: :disconnected,
            signed_params: %{},
            private: %{},
            assigns: %{}

end
