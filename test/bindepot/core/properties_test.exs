defmodule Bindepot.Core.PropertiesTest do
  alias Bindepot.Core.Properties

  use Bindepot.DataCase

  describe "properties" do
    test "creating a new property should succeed" do
      property_name = "tag"

      assert property_name == Properties.get_or_create_property(property_name).name
    end

    test "reusing an existing property should succeed" do
      property_name = "tag"

      created = Properties.get_or_create_property(property_name)
      reused = Properties.get_or_create_property(property_name)

      assert 1 == Enum.count(Properties.all())
      assert created.id == reused.id
      assert created.name == reused.name
      assert property_name == reused.name
    end

    test "creating multiple properties should succeed" do
      props = ["created", "updated", "deleted"]

      created =
        props
        |> Properties.get_or_create_properties()
        |> Enum.map(fn p -> p.name end)

      assert Enum.sort(props) == Enum.sort(created)
      assert 3 == Enum.count(created)
    end

    test "duplicate properties should be ignored while creating multiple properties" do
      props = ["created", "updated", "deleted", "created"]

      created =
        props
        |> Properties.get_or_create_properties()
        |> Enum.map(fn p -> p.name end)

      assert Enum.sort(Enum.uniq(props)) == Enum.sort(created)
      assert 3 == Enum.count(created)
    end
  end
end
