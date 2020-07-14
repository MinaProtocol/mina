defmodule ClassTest do
  # we do not want to run this test in parallel as it performs runtime module redefinition
  use ExUnit.Case, async: false
  doctest Class

  test "basic properties of class inheritance and instance relationships" do
    defmodule A do
      use Class
      defclass(x: integer)
    end

    defmodule B do
      use Class
      defclass(A, y: String.t())
    end

    defmodule C do
      use Class
      defclass(B, z: atom)
    end

    defmodule D do
      use Class
      defclass(B, k: module)
    end

    defmodule Test do
      import Class

      def run_test do
        a = %A{x: 1}
        b = %B{x: 2, y: "b"}
        c = %C{x: 3, y: "c", z: :test}
        d = %D{x: 4, y: "d", k: __MODULE__}

        assert is_class?(A)
        assert is_class?(B)
        assert is_class?(C)
        assert is_class?(D)

        assert is_subclass?(B, A)
        assert is_subclass?(C, A)
        assert is_subclass?(D, A)
        assert is_subclass?(C, B)
        assert is_subclass?(D, B)

        assert class_of(a) == A
        assert class_of(b) == B
        assert class_of(c) == C
        assert class_of(d) == D

        assert instance_of?(a, A)
        assert not instance_of?(a, B)
        assert not instance_of?(a, C)
        assert not instance_of?(a, D)
        assert instance_of?(b, A)
        assert instance_of?(b, B)
        assert not instance_of?(b, C)
        assert not instance_of?(b, D)
        assert instance_of?(c, A)
        assert instance_of?(c, B)
        assert instance_of?(c, C)
        assert not instance_of?(c, D)
        assert instance_of?(d, A)
        assert instance_of?(d, B)
        assert not instance_of?(d, C)
        assert instance_of?(d, D)
      end
    end

    Test.run_test()
  end

  test "instance downcasting" do
    defmodule A do
      use Class
      defclass(x: integer)
    end

    defmodule B do
      use Class
      defclass(A, y: integer)
    end

    defmodule C do
      use Class
      defclass(B, z: integer)
    end

    defmodule Test do
      alias Class.NotASubclassError
      import Class

      def run_test do
        a = %A{x: 1}
        b = %B{x: 1, y: 2}
        c = %C{x: 1, y: 2, z: 3}

        assert downcast!(a, A) == a
        assert_raise NotASubclassError, fn -> downcast!(a, B) end
        assert_raise NotASubclassError, fn -> downcast!(a, C) end
        assert downcast!(b, A) == a
        assert downcast!(b, B) == b
        assert_raise NotASubclassError, fn -> downcast!(b, C) end
        assert downcast!(c, A) == a
        assert downcast!(c, B) == b
        assert downcast!(c, C) == c
      end
    end

    Test.run_test()
  end

  test "hiearchy" do
    defmodule A do
      use Class
      defclass(x: integer)
    end

    defmodule B do
      use Class
      defclass(A, y: integer)
    end

    defmodule C do
      use Class
      defclass(B, z: integer)
    end

    defmodule D do
      use Class
      defclass(B, k: integer)
    end

    defmodule E do
      use Class
      defclass(A, d: integer)
    end

    defmodule F do
      use Class
      defclass(E, r: integer)
    end

    defmodule G do
      use Class
      defclass(D, w: integer)
    end

    defmodule H do
      use Class
      defclass(F, c: integer)
    end

    defmodule Test do
      import Class.Hiearchy

      def run_test do
        assert compute(A, [B]) ==
                 {A,
                  [
                    {B, []}
                  ]}

        assert compute(A, [C]) ==
                 {A,
                  [
                    {B,
                     [
                       {C, []}
                     ]}
                  ]}

        assert compute(A, [C]) == compute(A, [B, C])

        assert compute(A, [H]) ==
                 {A,
                  [
                    {E,
                     [
                       {F,
                        [
                          {H, []}
                        ]}
                     ]}
                  ]}

        assert compute(A, [C, G, H]) ==
                 {A,
                  [
                    {B,
                     [
                       {C, []},
                       {D,
                        [
                          {G, []}
                        ]}
                     ]},
                    {E,
                     [
                       {F,
                        [
                          {H, []}
                        ]}
                     ]}
                  ]}

        str =
          reduce_depth_first(
            compute(A, [C, G, H]),
            "",
            fn root, acc -> "#{List.last(Module.split(root))}:#{acc}" end,
            fn ls -> "(#{Enum.join(ls, ",")})" end
          )

        assert str == "A:(B:(C:,D:(G:)),E:(F:(H:)))"
      end
    end

    Test.run_test()
  end
end
