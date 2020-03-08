defmodule CliExDoc do
  require IEx.Helpers
  require CliExDoc.Macros

  def main(args) do
    IEx.configure(colors: [enabled: true])

    case args do
      [term] -> show_detail(term)
      _ -> CliExDoc.Macros.list_modules()
    end
  end

  def show_detail(term) do
    parse_mfa(term)
    |> validate_mfa()
    |> case do
      {:ok, mfa} -> IEx.Introspection.h(mfa)
      _ -> nil
    end
  end

  def parse_mfa(term) when is_binary(term) do
    String.split(term, ".")
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

  def validate_mfa(mfa), do: if(valid_mfa?(mfa), do: {:ok, mfa}, else: :error)

  def valid_mfa?({m, f, a}) do
    module_loaded?(m) &&
      m.__info__(:functions) |> Enum.member?({f, a})
  end

  def valid_mfa?({m, f}) do
    module_loaded?(m) &&
      m.__info__(:functions)
      |> Enum.map(fn {func, _} -> func end)
      |> Enum.member?(f)
  end

  def valid_mfa?(m) do
    module_loaded?(m)
  end

  def module_loaded?(m) do
    case Code.ensure_loaded(m) do
      {:module, _} -> true
      _ -> false
    end
  end
end
