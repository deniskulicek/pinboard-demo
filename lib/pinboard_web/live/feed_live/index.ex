defmodule PinboardWeb.FeedLive.Index do
  use PinboardWeb, :live_view
  alias PinboardWeb.Presence

  alias Pinboard.Posts
  alias Pinboard.Posts.Post

  @presence_topic "users:presence"

  # Render loading view initially while the socket is not connected
  @impl true
  def render(%{loading: true} = assigns) do
    ~H"""
    Loading...
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Helpful debug info --%>
    <div class="bg-slate-900 text-white overflow-auto text-xs h-[180px]">
      <p class="mb-2 font-black">Presences</p>
      <pre><%= inspect(@presences, pretty: true) %></pre>
      <p class="my-2 font-black">Diffs</p>
      <pre><%= inspect(@diff, pretty: true) %></pre>
    </div>

    <%!-- Project info --%>
    <div class="container">
      <h1 class="text-2xl">Welcome to your pinboard feed!</h1>
      <p class="my-2 text-gray-600">
        Try out real-time functionality by adding a comment below.
      </p>
      <ul class="text-xs">
        <li><b>Pro tip</b>: Open this page in multiple tabs to see the real-time updates.</li>
        <li><b>Pro pro tip</b>: Open in multiple browsers as different users!</li>
      </ul>
    </div>

    <%!-- Posts --%>
    <hr class="mt-4" />
    <.button type="button" class="my-4 w-full" phx-click={show_modal("new-post-modal")}>
      New Post
    </.button>

    <%!-- Presence tracking example --%>
    <div :for={{user_id, %{metas: metas}} <- @presences} id={user_id}>
      <%= if(contains_posting?(metas)) do
        user_presence = hd(metas)
        "#{user_presence.email} is about to post someting..."
      end %>
    </div>

    <%!-- New post modal --%>
    <.modal id="new-post-modal">
      <.simple_form for={@form} phx-change="validate" phx-submit="save-post">
        <.live_file_input upload={@uploads.image} required />
        <.input
          field={@form[:body]}
          type="textarea"
          label="Text"
          required
          phx-focus="start-posting"
          phx-blur="stop-posting"
        />
        <.button type="submit" phx-disable-with="Saving...">Create Post</.button>
      </.simple_form>
    </.modal>

    <%!-- List posts --%>
    <div id="feed" phx-update="stream" class="flex flex-col gap-4">
      <div
        :for={{post_id, post} <- @streams.posts}
        id={post_id}
        class="w-full mx-auto flex flex-col gap-4 p-4 border rounded-lg"
      >
        <h3 class="font-black text-left">
          By: <%= post.user.email %>
          <span class="px-1">
            <%= render_presence_status(@presences, post.user_id) %>
          </span>
        </h3>
        <a href={~p"/posts/#{post}"}>
          <img src={post.image_link} alt={post.body} class="w-1/2 flex m-auto rounded-lg" />
          <p class="text-sm text-gray-600 text-center italic"><%= post.body %></p>
        </a>
        <a class="uppercase underline text-xs" href={~p"/posts/#{post}"}>
          Comments (<%= length(post.comments) %>)
        </a>
        <ul class="text-xs">
          <li
            :for={comment <- post.comments}
            id={"comment-#{comment.id}"}
            class="flex flex-col gap-2 p-2 border rounded-lg"
          >
            <p class="text-xs text-gray-400">
              <%= comment.user.email %>
              <%= render_presence_status(@presences, comment.user_id) %>
            </p>
            <p class="text-gray-600">By: <%= comment.body %></p>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      %{current_user: current_user} = socket.assigns

      # initialize form
      form =
        %Post{}
        |> Post.changeset()
        |> to_form(as: "post")

      # Listen for new posts, process them in "handle_info" callback
      PinboardWeb.Endpoint.subscribe("posts")

      # Listen for new comments (this gets called in the show live view)
      PinboardWeb.Endpoint.subscribe("comments")

      # Subscribe to presence topic
      Phoenix.PubSub.subscribe(Pinboard.PubSub, @presence_topic)

      # Announce presence
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
        |> assign(diff: nil)
        |> allow_upload(:image, accept: ~w(.png .jpg), max_entries: 1)
        |> stream(:posts, Posts.list_all())

      {:ok, socket}
    else
      {:ok, assign(socket, loading: true)}
    end
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    post =
      %Post{}
      |> Post.changeset(post_params)
      |> to_form(as: "post")

    {:noreply, assign(socket, form: post)}
  end

  @impl true
  def handle_event("save-post", %{"post" => post_params} = _params, socket) do
    post_params
    |> Map.put("user_id", socket.assigns.current_user.id)
    |> Map.put("image_link", consume_files(socket) |> List.first())
    |> Posts.save()
    |> case do
      {:ok, post} ->
        socket =
          socket
          |> put_flash(:info, "Post created!")
          |> push_navigate(to: ~p"/feed")

        # Broadcast the new post to all subscribers
        post_with_user = Map.put(post, :user, socket.assigns.current_user)
        PinboardWeb.Endpoint.broadcast("posts", "new_post", post_with_user)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: changeset)}
    end
  end

  # Handle presence events
  def handle_event("start-posting", _params, socket) do
    %{current_user: current_user} = socket.assigns

    Presence.update(self(), @presence_topic, current_user.id, fn state ->
      Map.put(state, :is_posting, true)
    end)

    {:noreply, socket}
  end

  # Handle stop posting event, broadcast presence update that user is no longer "posting"
  def handle_event("stop-posting", _params, socket) do
    %{current_user: current_user} = socket.assigns

    Presence.update(self(), @presence_topic, current_user.id, fn state ->
      Map.put(state, :is_posting, false)
    end)

    {:noreply, socket}
  end

  defp contains_posting?(metas) do
    # Users can have multiple presences, mark them as posting if they are posting in any of them
    Enum.any?(metas, & &1.is_posting)
  end

  defp render_presence_status(presences, user_id) when is_integer(user_id) do
    if presences[user_id |> Integer.to_string()], do: "🟢", else: "🔴"
  end

  defp render_presence_status(presences, user_id) do
    if presences[user_id], do: "🟢", else: "🔴"
  end

  # Handle new posts broadcasted from the server
  @impl true
  def handle_info(%{event: "new_post", payload: post}, socket) do
    socket =
      socket
      |> put_flash(:info, "New post created")
      |> stream_insert(:posts, post, at: 0)

    {:noreply, socket}
  end

  # Handle new comment broadcasted from the server - monkey patch posts list
  @impl true
  def handle_info(%{event: "new_post_comment", payload: comment}, socket) do
    # can't do this because we streamed the posts
    # posts =
    #  socket.assigns.streams.posts
    #  |> Enum.map(fn post ->
    #    if post.id == comment.post_id do
    #      Map.put(post, :comments, [comment | post.comments])
    #    else
    #      post
    #    end
    #  end)

    # refetch the post (because we streamed it and are not keeping it in memory)
    post = Posts.show(comment.post_id)

    socket =
      socket
      |> put_flash(:info, "New comment: #{comment.body}")
      |> stream_insert(:posts, post)

    {:noreply, socket}
  end

  # Presence updates
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    socket =
      socket
      |> Presence.handle_diff(diff)
      |> stream(:posts, Posts.list_all())

    # we reloaded posts here to get updated user presence status in the UI
    {:noreply, socket}
  end

  # https://hexdocs.pm/phoenix_live_view/uploads.html#consume-uploaded-entries
  defp consume_files(socket) do
    consume_uploaded_entries(socket, :image, fn %{path: path}, _entry ->
      dest = Path.join(Application.app_dir(:pinboard, "priv/static/uploads"), Path.basename(path))
      # You will need to create `priv/static/uploads` for `File.cp!/2` to work.
      File.cp!(path, dest)
      {:ok, ~p"/uploads/#{Path.basename(dest)}"}
    end)
  end
end
