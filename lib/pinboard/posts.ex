defmodule Pinboard.Posts do
  import Ecto.Query

  alias Pinboard.Repo
  alias Pinboard.Posts.Post
  alias Pinboard.Posts.Comment

  def list_all() do
    Post
    |> order_by(desc: :id)
    |> preload(:user)
    |> preload(comments: :user)
    |> Repo.all()
  end

  def show(id) do
    Post
    |> Repo.get(id)
    |> Repo.preload(:user)
    |> Repo.preload(comments: :user)
  end

  def insert_comment(comment_params) do
    %Comment{}
    |> Comment.changeset(comment_params)
    |> Repo.insert()
  end

  def save(post_params) do
    %Post{}
    |> Post.changeset(post_params)
    |> Repo.insert()
  end
end
