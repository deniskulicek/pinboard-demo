defmodule Pinboard.Posts.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pinboard.Accounts.User
  alias Pinboard.Posts.Post

  schema "comments" do
    field :body, :string
    belongs_to :user, User
    belongs_to :post, Post

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs \\ %{}) do
    comment
    |> cast(attrs, [:body, :user_id, :post_id])
    |> validate_required([:body, :user_id, :post_id])
  end
end
