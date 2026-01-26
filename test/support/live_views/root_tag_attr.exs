# Note this file is intentionally a .exs file because it is loaded
# in the test helper with :root_tag_attribute turned on.
defmodule Phoenix.LiveViewTest.Support.RootTagAttr do
  use Phoenix.Component

  defmodule RootTagsWithValuesMacroComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def transform(_ast, _meta) do
      {:ok, "", %{},
       [
         root_tag_attribute: {"phx-sample-one", "test"},
         root_tag_attribute: {"phx-sample-two", "test"}
       ]}
    end
  end

  defmodule RootTagsWithoutValuesMacroComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def transform(_ast, _meta) do
      {:ok, "", %{},
       [
         root_tag_attribute: {"phx-sample-one", true},
         root_tag_attribute: {"phx-sample-two", true}
       ]}
    end
  end

  def macro_component_attrs_with_values_within_nestings(assigns) do
    ~H"""
    <div :type={Phoenix.LiveViewTest.Support.RootTagAttr.RootTagsWithValuesMacroComponent}></div>
    <%= if true do %>
      <div>
        <div>
          <%= if @bool do %>
            <.inner_block_and_slot>
              <p>
                <span>True</span>
              </p>
            </.inner_block_and_slot>
          <% else %>
            <.inner_block_and_slot>
              <p>
                <span>False</span>
              </p>
            </.inner_block_and_slot>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def within_nestings(assigns) do
    ~H"""
    <%= if true do %>
      <div>
        <div>
          <%= if @bool do %>
            <.inner_block_and_slot>
              <p>
                <span>True</span>
              </p>
            </.inner_block_and_slot>
          <% else %>
            <.inner_block_and_slot>
              <p>
                <span>False</span>
              </p>
            </.inner_block_and_slot>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def macro_component_attrs_with_values(assigns) do
    ~H"""
    <div :type={Phoenix.LiveViewTest.Support.RootTagAttr.RootTagsWithValuesMacroComponent}></div>
    <div>
      <div>
        <.inner_block_and_slot>
          <div>Inner Block</div>
          <:test>
            <div>
              Named Slot
            </div>
          </:test>
        </.inner_block_and_slot>
      </div>
    </div>
    """
  end

  def macro_component_attrs_without_values(assigns) do
    ~H"""
    <div :type={Phoenix.LiveViewTest.Support.RootTagAttr.RootTagsWithoutValuesMacroComponent}></div>
    <div>
      <div>
        <.inner_block_and_slot>
          <div>Inner Block</div>
          <:test>
            <div>
              Named Slot
            </div>
          </:test>
        </.inner_block_and_slot>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true
  slot :test

  def single_self_close(assigns) do
    ~H"""
    <div />
    """
  end

  def single_with_body(assigns) do
    ~H"""
    <div>Test</div>
    """
  end

  def multiple_self_close(assigns) do
    ~H"""
    <div />
    <div />
    <div />
    """
  end

  def multiple_with_bodies(assigns) do
    ~H"""
    <div>Test1</div>
    <div>Test2</div>
    <div>Test3</div>
    """
  end

  def nested_tags(assigns) do
    ~H"""
    <div>
      <div>
        <div></div>
      </div>
      <div>
        <div></div>
      </div>
    </div>
    <div>
      <div>
        <div></div>
      </div>
      <div>
        <div></div>
      </div>
    </div>
    """
  end

  def component_inner_blocks(assigns) do
    ~H"""
    <div>
      <div>
        <.inner_block_and_slot>
          <div>
            <div>
              Inner Block 1
            </div>
          </div>
        </.inner_block_and_slot>
        <.inner_block_and_slot>
          <div>
            <div>
              Inner Block 2
            </div>
          </div>
        </.inner_block_and_slot>
      </div>
    </div>
    """
  end

  def component_named_slots(assigns) do
    ~H"""
    <div>
      <div>
        <.inner_block_and_slot>
          <:test>
            <div>
              <div>
                Inner Block 1
              </div>
            </div>
          </:test>
        </.inner_block_and_slot>
        <.inner_block_and_slot>
          <:test>
            <div>
              <div>
                Inner Block 2
              </div>
            </div>
          </:test>
        </.inner_block_and_slot>
      </div>
    </div>
    """
  end

  def nested_tags_components_slots(assigns) do
    ~H"""
    <div>
      <div>
        <.inner_block_and_slot>
          <div>
            <.inner_block_and_slot>
              <div>
                <.simple />
              </div>
              <:test>
                <div>
                  <.simple />
                </div>
              </:test>
            </.inner_block_and_slot>
          </div>
          <:test>
            <div>
              <.inner_block_and_slot>
                <div>
                  <.simple />
                </div>
                <:test>
                  <div>
                    <.simple />
                  </div>
                </:test>
              </.inner_block_and_slot>
            </div>
          </:test>
        </.inner_block_and_slot>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true
  slot :test

  defp inner_block_and_slot(assigns) do
    ~H"""
    <section>
      {render_slot(@inner_block)}
      <aside :for={test <- @test}>
        {render_slot(@test)}
      </aside>
    </section>
    """
  end

  defp simple(assigns) do
    ~H"""
    <p>Simple</p>
    """
  end
end
