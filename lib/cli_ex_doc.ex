defmodule ExDocShell do
  require IEx.Helpers
  require ExDocShell.Macros

  def main(args) do
    {width, _} = System.get_env("EXDOC_WIDTH", "80") |> Integer.parse()
    IEx.configure(colors: [enabled: true], width: width)

    case args do
      [term] -> show_detail(term)
      _ -> ExDocShell.Macros.list_modules()
    end
  end

  def show_detail(term) do
    parse_mfa(term)
    |> tag_mfa()
    |> case do
      {:function, mfa} -> IEx.Introspection.h(mfa)
      {:module, mfa} -> IEx.Introspection.h(mfa)
      {:callback, mfa} -> IEx.Introspection.b(mfa)
      _ -> nil
    end
  end

  def parse_mfa(term) when is_binary(term) do
    String.split(term, ".")
    |> Enum.chunk_by(fn part -> Regex.match?(~r/^[A-Z].*/, part) end)
    |> then(fn
      [module] -> [Enum.join(module, ".")]
      [module, [func]] -> [Enum.join(module, "."), func]
    end)
    |> parse_mfa
  end

  def parse_mfa([module_name]) do
    String.to_atom("Elixir." <> module_name)
  end

  def parse_mfa([module_name, func]) when is_binary(func) do
    [module_name, String.split(func, "/")]
    |> parse_mfa()
  end

  def parse_mfa([module_name, [func]]) do
    {String.to_atom("Elixir." <> module_name), String.to_atom(func)}
  end

  def parse_mfa([module_name, [func, arity]]) do
    {String.to_atom("Elixir." <> module_name), String.to_atom(func), String.to_integer(arity)}
  end

  def tag_mfa(mfa) do
    cond do
      is_callback?(mfa) -> {:callback, mfa}
      is_function?(mfa) -> {:function, mfa}
      is_module?(mfa) -> {:module, mfa}
      true -> :error
    end
  end

  def is_callback?({m, f, a}) do
    module_loaded?(m) &&
      Code.Typespec.fetch_callbacks(m)
      |> then(fn {:ok, callbacks} -> callbacks end)
      |> Enum.map(fn {name_arity, _} -> name_arity end)
      |> Enum.member?({f, a})
  end

  def is_callback?({m, f}) do
    module_loaded?(m) &&
      Code.Typespec.fetch_callbacks(m)
      |> then(fn {:ok, callbacks} -> callbacks end)
      |> Enum.map(fn {name_arity, _} -> name_arity end)
      |> Enum.map(fn {func, _} -> func end)
      |> Enum.member?(f)
  end

  def is_callback?(_m), do: false

  def is_function?({m, f, a}) do
    module_loaded?(m) && m.__info__(:functions) |> Enum.member?({f, a})
  end

  def is_function?({m, f}) do
    module_loaded?(m) &&
      m.__info__(:functions)
      |> Enum.map(fn {func, _} -> func end)
      |> Enum.member?(f)
  end

  def is_function?(_m), do: false

  def is_module?({_m, _f, _a}), do: false

  def is_module?({_m, _f}), do: false

  def is_module?(m) do
    module_loaded?(m)
  end

  def module_loaded?(m) do
    case Code.ensure_loaded(m) do
      {:module, _} -> true
      _ -> false
    end
  end
end
