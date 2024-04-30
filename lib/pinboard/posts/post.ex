defmodule Pinboard.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pinboard.Accounts.User
  alias Pinboard.Posts.Comment

  schema "posts" do
    field :body, :string
    field :image_link, :string
    belongs_to :user, User
    has_many :comments, Comment, preload_order: [desc: :id]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs \\ %{}) do
    post
    |> cast(attrs, [:body, :image_link, :user_id])
    |> validate_required([:body, :user_id])
  end
end
