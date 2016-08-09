defmodule CodeCorps.Role do
  use CodeCorps.Web, :model

  schema "roles" do
    field :name, :string
    field :ability, :string
    field :kind, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :ability, :kind])
    |> validate_required([:name, :ability, :kind])
    |> validate_inclusion(:kind, kinds)
  end

  def kinds do
    ~w{ technology creative support }
  end
end
