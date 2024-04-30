defmodule PinboardWeb.Presence do
  import Phoenix.Component, only: [assign: 3]

  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :pinboard,
    pubsub_server: Pinboard.PubSub

  # Presence diffing helpers
  def handle_diff(socket, diff) do
    socket
    # we don't actually need the diff, but it's useful for debugging
    |> assign(:diff, diff)
    |> remove_presences(diff.leaves)
    |> add_presences(diff.joins)
  end

  defp remove_presences(socket, leaves) do
    presences = socket.assigns.presences

    left_refs =
      Enum.map(leaves, fn {_user_id, %{metas: metalist}} ->
        Enum.map(metalist, & &1.phx_ref)
      end)
      |> List.flatten()

    reject_left_refs = fn metas ->
      Enum.reject(metas, fn entry ->
        Enum.member?(left_refs, entry.phx_ref)
      end)
    end

    updated_presences =
      presences
      |> Enum.reduce(%{}, fn {user_id, %{metas: metas}}, acc ->
        new_metas = reject_left_refs.(metas)

        if(Enum.empty?(new_metas)) do
          acc
        else
          Map.put(acc, user_id, %{metas: new_metas})
        end
      end)

    assign(socket, :presences, updated_presences)
  end

  defp add_presences(socket, joins) do
    presences = socket.assigns.presences

    updated_presences =
      Enum.map(joins, fn {user_id, %{metas: metas}} ->
        prev_metas = Map.get(presences, user_id)

        new_metas =
          if(prev_metas) do
            # additional user presence session
            [metas | prev_metas.metas] |> List.flatten() |> Enum.uniq()
          else
            # new user presence session
            metas
          end

        {user_id, %{metas: new_metas}}
      end)
      |> Enum.into(%{})

    assign(socket, :presences, Map.merge(presences, updated_presences))
  end
end
