defmodule ArchitectureTests.LogFilterTest do
  use ExUnit.Case
  doctest Architecture.LogFilter

  import Architecture.LogFilter
  import Architecture.LogFilter.Language
  require Architecture.LogFilter.Language

  test "simple dsl construction" do
    example =
      filter do
        a.b == "test123"
        xYz == "logs"
        x["~~"].z <~> "indices" or z.y == "nothing"
        "world"
      end

    assert example ==
             adjoin([
               equals(["a", "b"], "test123"),
               equals(["xYz"], "logs"),
               disjoin(
                 contains(["x", "~~", "z"], "indices"),
                 equals(["z", "y"], "nothing")
               ),
               global_restriction("world")
             ])
  end

  test "dsl comparison rhs interpolation support" do
    y = "asdf"
    example = filter(do: x == "#{y}123")

    assert example == equals(["x"], "asdf123")
  end
end
