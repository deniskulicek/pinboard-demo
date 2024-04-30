defmodule Pinboard.Posts do
  alias Pinboard.Repo
  alias Pinboard.Posts.Post

  def list_all() do
    Post
    |> Repo.all()
  end

  def save(post_params) do
    %Post{}
    |> Post.changeset(post_params)
    |> Repo.insert()
  end
end
