defmodule PinboardWeb.PostsLive.Show do
  use PinboardWeb, :live_view
  alias PinboardWeb.Presence

  alias Pinboard.Posts
  alias Pinboard.Posts.Comment

  @presence_topic "users:presence"

  @impl true
  def mount(%{"id" => id} = _params, _session, socket) do
    if connected?(socket) do
      %{current_user: current_user} = socket.assigns

      # initialize comment form
      form =
        %Comment{}
        |> Comment.changeset()
        |> to_form(as: "comment")

      # Listen for new comments, process them in "handle_info" callback
      PinboardWeb.Endpoint.subscribe("post:#{id}:comments")

      # Subscribe to presence topic
      Phoenix.PubSub.subscribe(Pinboard.PubSub, @presence_topic)

      # Announce presence - ideally we want to do this in a shared live component (not duplicated in every live view)
      {:ok, _} =
        Presence.track(self(), @presence_topic, current_user.id, %{
          is_typing_post_id: nil,
          is_posting: false,
          email: current_user.email
        })

      presences = Presence.list(@presence_topic)

      socket =
        socket
        |> assign(form: form)
        |> assign(loading: false)
        |> assign(presences: presences)
        |> assign(:post, Posts.show(id))

      {:ok, socket}
    else
      {:ok, assign(socket, loading: true)}
    end
  end

  # Form handling
  @impl true
  def handle_event("validate", %{"comment" => comment_params}, socket) do
    comment =
      %Comment{}
      |> Comment.changeset(comment_params)
      |> to_form(as: "comment")

    {:noreply, assign(socket, form: comment)}
  end

  @impl true
  def handle_event("send-comment", %{"comment" => comment_params} = _params, socket) do
    current_user = socket.assigns.current_user
    post = socket.assigns.post

    comment_params
    |> Map.put("user_id", current_user.id)
    |> Map.put("post_id", post.id)
    |> Posts.insert_comment()
    |> case do
      {:ok, comment} ->
        socket =
          socket
          |> put_flash(:info, "Comment added!")
          |> push_navigate(to: ~p"/posts/#{post.id}")

        # Broadcast the new post to all subscribers
        comment_data = Map.put(comment, :user, current_user) |> Map.put(:post, post)
        PinboardWeb.Endpoint.broadcast("post:#{post.id}:comments", "new_comment", comment_data)
        PinboardWeb.Endpoint.broadcast("comments", "new_post_comment", comment_data)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: changeset)}
    end
  end

  # Handle presence events
  def handle_event("start-typing", _params, socket) do
    %{current_user: current_user, post: post} = socket.assigns

    Presence.update(self(), @presence_topic, current_user.id, fn state ->
      Map.put(state, :is_typing_post_id, post.id)
    end)

    {:noreply, socket}
  end

  def handle_event("stop-typing", _params, socket) do
    %{current_user: current_user} = socket.assigns

    Presence.update(self(), @presence_topic, current_user.id, fn state ->
      Map.put(state, :is_typing_post_id, nil)
    end)

    {:noreply, socket}
  end

  # Handle new comment broadcasted from the server
  @impl true
  def handle_info(%{event: "new_comment", payload: comment}, socket) do
    post = socket.assigns.post
    post = Map.put(post, :comments, [comment | post.comments])

    # patch the socket with the updated post
    socket =
      socket
      |> put_flash(:info, "New comment created")
      |> assign(:post, post)

    {:noreply, socket}
  end

  # Presence updates
  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    socket =
      socket
      |> Presence.handle_diff(diff)

    {:noreply, socket}
  end

  defp render_presence_status(presences, user_id) when is_integer(user_id) do
    if presences[user_id |> Integer.to_string()], do: "🟢", else: "🔴"
  end

  defp render_presence_status(presences, user_id) do
    if presences[user_id], do: "🟢", else: "🔴"
  end

  defp is_typing_on_post?(post, metas) do
    # Users can have multiple presences, mark them as typing if they are typing in any of them
    Enum.any?(metas, &(&1.is_typing_post_id == post.id))
  end
end
