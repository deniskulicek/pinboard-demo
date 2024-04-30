defmodule Pinboard.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pinboard.Accounts.User

  schema "posts" do
    field :body, :string
    field :image_link, :string
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:body, :image_link, :user_id])
    |> validate_required([:text, :user_id])
  end
end