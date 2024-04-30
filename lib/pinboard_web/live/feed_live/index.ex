defmodule PinboardWeb.FeedLive.Index do
  use PinboardWeb, :live_view
  alias Pinboard.Posts
  alias Pinboard.Posts.Post
  alias Pinboard.Posts.Comment

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
    <hr class="my-4" />
    <.button type="button" class="mb-2" phx-click={show_modal("new-post-modal")}>
      New Post
    </.button>
    <.modal id="new-post-modal">
      <.simple_form for={@form} phx-change="validate" phx-submit="save-post">
        <.live_file_input upload={@uploads.image} required />
        <.input field={@form[:body]} type="textarea" label="Text" required />
        <.button type="submit" phx-disable-with="Saving...">Create Post</.button>
      </.simple_form>
    </.modal>

    <%!-- List posts --%>
    <div id="feed" phx-update="stream" class="flex flex-col gap-4">
      <div
        :for={{post_id, post} <- @streams.posts}
        id={post_id}
        class="w-full mx-auto flex flex-col gap-4 p-4 border rounded"
      >
        <h3 class="font-black text-left">By: <%= post.user.email %></h3>
        <img src={post.image_link} alt={post.body} class="w-1/2 flex m-auto rounded" />
        <p class="text-sm text-gray-600 text-center italic"><%= post.body %></p>
        <h4 class="uppercase underline text-xs">Comments</h4>
        <p>todo</p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # initialize form
      form =
        %Post{}
        |> Post.changeset()
        |> to_form(as: "post")

      # Listen for new posts, process them in "handle_info" callback
      PinboardWeb.Endpoint.subscribe("posts")

      socket =
        socket
        |> assign(form: form)
        |> assign(loading: false)
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
        PinboardWeb.Endpoint.broadcast("posts", "new_post", post)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: changeset)}
    end
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
