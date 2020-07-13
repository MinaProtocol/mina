defmodule Architecture.LogFilter do
  @moduledoc "A generalized language for representing log filters."

  @type selection :: [String.t()]

  # TODO: remove global_restriction support in favor of local restrictions on messages?
  @type t ::
          {:global_restriction, String.t()}
          | {:equals | :contains, selection, String.t()}
          | {:adjunction | :disjunction, [t]}
          | String.t()
          | nil

  # Simple Constructors

  @spec global_restriction(String.t()) :: t
  def global_restriction(str), do: {:global_restriction, str}

  @spec equals(selection, String.t()) :: t
  def equals(sel, str), do: {:equals, sel, str}

  @spec contains(selection, String.t()) :: t
  def contains(sel, str), do: {:contains, sel, str}

  # Filter Combinators

  @spec adjoin(t, t) :: t
  def adjoin(nil, b), do: b
  def adjoin(a, nil), do: a
  # IMPLIED: def adjoin(nil, nil), do: nil
  def adjoin({:adjunction, a}, {:adjunction, b}), do: {:adjunction, a ++ b}
  def adjoin({:adjunction, a}, b), do: {:adjunction, a ++ [b]}
  def adjoin(a, {:adjunction, b}), do: {:adjunction, [a | b]}
  def adjoin(a, b), do: {:adjunction, [a, b]}

  @spec adjoin([t] | nil) :: t
  def adjoin(nil), do: nil
  def adjoin([]), do: nil
  def adjoin(ls) when is_list(ls), do: Enum.reduce(ls, &adjoin(&2, &1))

  @spec disjoin(t, t) :: t
  def disjoin(nil, b), do: b
  def disjoin(a, nil), do: a
  # IMPLIED: def adjoin(nil, nil), do: nil
  def disjoin({:disjunction, a}, {:disjunction, b}), do: {:disjunction, a ++ b}
  def disjoin({:disjunction, a}, b), do: {:disjunction, a ++ [b]}
  def disjoin(a, {:disjunction, b}), do: {:disjunction, [a | b]}
  def disjoin(a, b), do: {:disjunction, [a, b]}

  @spec disjoin([t] | nil) :: t
  def disjoin(nil), do: nil
  def disjoin([]), do: nil
  def disjoin(ls) when is_list(ls), do: Enum.reduce(ls, &disjoin(&2, &1))

  @spec nest(String.t()) :: String.t()
  defp nest(str), do: "(#{str})"

  # Filter Rendering
  # TODO: split this off into a LogEngine abstraction
  # TODO: apply stack driver specific optimizations (e.g. `a = "a" OR a = "b"` can be optimized to `a = ("a" OR "b")`)

  @spec render_string(String.t()) :: String.t()
  defp render_string(str) when is_binary(str) do
    escaped_str = String.replace(str, "\"", "\\\"")
    "\"#{escaped_str}\""
  end

  # TODO: custom selection part escape logic (will reduce the size of rendered filters)
  # for now, we just wrap all selection parts in strings to avoid special escape logic
  @spec render_selection(selection) :: String.t()
  defp render_selection(sel), do: sel |> Enum.map(&render_string/1) |> Enum.join(".")

  @spec render_comparison(selection, String.t()) :: String.t()
  defp render_comparison(sel, str), do: "#{render_selection(sel)}=#{render_string(str)}"

  @spec render_conjunction([t], String.t()) :: String.t()
  defp render_conjunction(ts, joinder) do
    ts
    |> Enum.map(&render_inner/1)
    |> Enum.join("#{joinder}")
  end

  @spec render_inner(t) :: String.t()
  defp render_inner(nil), do: ""
  defp render_inner(str) when is_binary(str), do: str
  defp render_inner({:global_restriction, str}), do: render_string(str)
  defp render_inner({:equals, sel, str}), do: render_comparison(sel, str)
  defp render_inner({:contains, sel, str}), do: render_comparison(sel, str)
  defp render_inner({:adjunction, ts}), do: nest(render_conjunction(ts, " AND "))
  defp render_inner({:disjunction, ts}), do: nest(render_conjunction(ts, " OR "))

  @spec render(t) :: String.t()
  def render({:adjunction, ts}), do: render_conjunction(ts, "\n")
  def render(t), do: render_inner(t)
end

defmodule Architecture.LogFilter.Language do
  @moduledoc "A DSL for constructing log filters."

  defmodule SyntaxError do
    defexception [:syntax, :error]

    def message(%__MODULE__{syntax: syntax, error: error}) do
      # "#{error} [offending syntax: `#{Macro.to_string(syntax)}`]"
      "#{error} [offending syntax: `#{Macro.to_string(syntax)}`; `#{inspect(syntax)}`]"
    end
  end

  @spec parse_string(Macro.t()) :: Macro.t()
  defp parse_string(x) when is_binary(x), do: Macro.escape(x)
  defp parse_string({:<<>>, _, _} = x), do: x

  defp parse_string(syntax) do
    raise SyntaxError,
      syntax: syntax,
      error: "right hand side of `==` or `<~>` must be a string"
  end

  @spec parse_selection(Macro.t()) :: Architecture.LogFilter.selection()
  defp parse_selection({{:., _, [head, tail]}, _, []}) when is_atom(tail),
    do: parse_selection(head) ++ [to_string(tail)]

  defp parse_selection({{:., _, [Access, :get]}, _, [head, tail]}),
    do: parse_selection(head) ++ [to_string(tail)]

  defp parse_selection({base, _, _}) when is_atom(base), do: [to_string(base)]

  defp parse_selection(syntax) do
    raise SyntaxError,
      syntax: syntax,
      error: "invalid log data selector (left hand side of comparision operators)"
  end

  @spec parse_filter(Macro.t()) :: Macro.t()
  defp parse_filter({:=, _, _} = syntax) do
    raise SyntaxError,
      syntax: syntax,
      error: "`=` not supported in log filters; use `==` for equality instead"
  end

  defp parse_filter({:==, _, [a, b]}) do
    quote do:
            unquote(Architecture.LogFilter).equals(
              unquote(parse_selection(a)),
              unquote(parse_string(b))
            )
  end

  defp parse_filter({:<~>, _, [a, b]}) do
    quote do:
            unquote(Architecture.LogFilter).contains(
              unquote(parse_selection(a)),
              unquote(parse_string(b))
            )
  end

  defp parse_filter({:and, _, [a, b]}) do
    quote do:
            unquote(Architecture.LogFilter).adjoin(
              unquote(parse_filter(a)),
              unquote(parse_filter(b))
            )
  end

  defp parse_filter({:or, _, [a, b]}) do
    quote do:
            unquote(Architecture.LogFilter).disjoin(
              unquote(parse_filter(a)),
              unquote(parse_filter(b))
            )
  end

  defp parse_filter(syntax) do
    quote do: unquote(Architecture.LogFilter).global_restriction(unquote(parse_string(syntax)))
  rescue
    SyntaxError ->
      reraise SyntaxError, [syntax: syntax, error: "invalid filter syntax"], __STACKTRACE__
  end

  defmacro filter(do: {:__block__, _, body}) do
    quote do: unquote(Architecture.LogFilter).adjoin(unquote(Enum.map(body, &parse_filter/1)))
  end

  defmacro filter(do: filter), do: parse_filter(filter)
end
