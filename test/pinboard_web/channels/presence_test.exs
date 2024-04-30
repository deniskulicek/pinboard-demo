defmodule PinboardWeb.PresenceTest do
  use PinboardWeb.ConnCase, async: true

  @base_presences %{
    "1" => %{
      metas: [
        %{phx_ref: "AAA", is_posting: false}
      ]
    }
  }

  @multiple_presences %{
    "1" => %{
      metas: [
        %{phx_ref: "AAA", is_posting: false},
        %{phx_ref: "A2", is_posting: false}
      ]
    }
  }

  @joins_diff %{
    joins: %{"2" => %{metas: [%{phx_ref: "BBB", is_posting: false}]}},
    leaves: %{}
  }

  @leaves_diff %{
    joins: %{},
    leaves: %{"1" => %{metas: [%{phx_ref: "AAA", is_posting: false}]}}
  }

  describe "PinboardWeb.Presence.handle_diff/2" do
    test "adds presence when presented with joins diff" do
      socket =
        %Phoenix.LiveView.Socket{}
        |> Phoenix.Component.assign(:presences, @base_presences)
        |> PinboardWeb.Presence.handle_diff(@joins_diff)

      assert %{
               "1" => %{metas: [%{phx_ref: "AAA", is_posting: false}]},
               "2" => %{metas: [%{phx_ref: "BBB", is_posting: false}]}
             } = socket.assigns.presences
    end

    test "removes presence when presented with leaves diff" do
      socket =
        %Phoenix.LiveView.Socket{}
        |> Phoenix.Component.assign(:presences, @base_presences)
        |> PinboardWeb.Presence.handle_diff(@leaves_diff)

      assert %{} = socket.assigns.presences
    end

    test "when dealing with multiple presences only removes the leaving presence" do
      socket =
        %Phoenix.LiveView.Socket{}
        |> Phoenix.Component.assign(:presences, @multiple_presences)
        |> PinboardWeb.Presence.handle_diff(@leaves_diff)

      assert %{
               "1" => %{metas: [%{phx_ref: "A2", is_posting: false}]}
             } = socket.assigns.presences
    end
  end
end
