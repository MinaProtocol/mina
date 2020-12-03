defmodule ArchitectureTests.ResourceSetTest do
  use ExUnit.Case, async: true
  doctest Architecture.ResourceSet

  alias Architecture.Resource
  alias Architecture.ResourceSet

  import Architecture.LogFilter.Language
  require Architecture.LogFilter.Language

  test "filter calculation" do
    defmodule A do
      use Resource
      require Architecture.LogFilter.Language
      defresource(x: integer)
      @impl true
      def global_filter do
        filter do
          name <~> "a"
        end
      end

      @impl true
      def local_filter(%__MODULE__{x: x}) do
        filter do
          data.a == "#{x}"
        end
      end
    end

    defmodule B do
      use Resource
      require Architecture.LogFilter.Language
      defresource(A, y: integer)
      @impl true
      def global_filter do
        filter do
          name <~> "b"
        end
      end

      @impl true
      def local_filter(%__MODULE__{y: y}) do
        filter do
          data.b == "#{y}"
        end
      end
    end

    defmodule C do
      use Resource
      require Architecture.LogFilter.Language
      defresource(A, z: integer)
      @impl true
      def global_filter do
        filter do
          name <~> "c"
        end
      end

      @impl true
      def local_filter(%__MODULE__{z: z}) do
        filter do
          data.c == "#{z}"
        end
      end
    end

    defmodule Test do
      import Architecture.LogFilter.Language
      require Architecture.LogFilter.Language

      def run do
        resources = [
          %A{x: 0},
          %B{x: 1, y: 2},
          %B{x: 2, y: 3},
          %C{x: 3, z: 0}
        ]

        resource_filter =
          resources
          |> ResourceSet.build()
          |> ResourceSet.filter()

        expected_filter =
          filter do
            name <~> "a"

            data.a == "0" or
              (name <~> "b" and
                 ((data.a == "1" and data.b == "2") or
                    (data.a == "2" and data.b == "3"))) or
              (name <~> "c" and (data.a == "3" and data.c == "0"))
          end

        assert resource_filter == expected_filter
      end
    end

    Test.run()
  end
end
