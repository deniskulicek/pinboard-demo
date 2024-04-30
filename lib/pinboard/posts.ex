defmodule Pinboard.Posts do
  import Ecto.Query

  alias Pinboard.Repo
  alias Pinboard.Posts.Post

  def list_all() do
    Post
    |> order_by(desc: :id)
    |> preload(:user)
    |> Repo.all()
  end

  def save(post_params) do
    %Post{}
    |> Post.changeset(post_params)
    |> Repo.insert()
  end
end
