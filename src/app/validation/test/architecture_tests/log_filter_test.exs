defmodule ArchitectureTests.LogFilterTest do
  use ExUnit.Case, async: true
  doctest Architecture.LogFilter

  import Architecture.LogFilter
  import Architecture.LogFilter.Language
  require Architecture.LogFilter.Language

  defp test_combinator(c1, c2, a, b) do
    assert c2.(a, nil) == c2.(nil, a)
    assert c2.(b, nil) == c2.(nil, b)
    assert c1.([a, nil]) == c1.([nil, a])
    assert c1.([b, nil]) == c1.([nil, b])
    assert c1.([a, b]) == c2.(a, b)
    assert c1.([b, a]) == c2.(b, a)
  end

  test "filter combinators" do
    x = equals(["a"], "x")
    y = equals(["b"], "y")
    z = equals(["c"], "z")
    test_combinator(&adjoin/1, &adjoin/2, x, y)
    test_combinator(&adjoin/1, &adjoin/2, adjoin(x, y), z)
    test_combinator(&adjoin/1, &adjoin/2, disjoin(x, y), z)
    test_combinator(&disjoin/1, &disjoin/2, x, y)
    test_combinator(&disjoin/1, &disjoin/2, adjoin(x, y), z)
    test_combinator(&disjoin/1, &disjoin/2, disjoin(x, y), z)
  end

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

  test "StackDriver rendering" do
    example1 =
      filter do
        a.b == "x"
        c <~> "z"
        a.c["_z"] == "123" or a["~"] == "5"
        a == "x" and b == "y"
        "global"
      end

    assert render(example1) ==
             """
             "a"."b"="x"
             "c"="z"
             ("a"."c"."_z"="123" OR "a"."~"="5")
             "a"="x"
             "b"="y"
             "global"\
             """

    example2 = disjoin(equals(["a"], "x"), equals(["a"], "z"))

    assert render(example2) ==
             """
             ("a"="x" OR "a"="z")\
             """
  end
end
