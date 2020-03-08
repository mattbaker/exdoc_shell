defmodule CliExDoc.Macros do
  defmacro list_modules() do
    modules_from_applications =
      for [app] <- :ets.match(:ac_tab, {{:loaded, :"$1"}, :_}),
          {:ok, modules} = :application.get_key(app, :modules),
          module <- modules do
        module
      end

    modules =
      :code.all_loaded()
      |> Enum.map(fn {module, _} -> module end)
      |> Kernel.++(modules_from_applications)
      |> Enum.uniq()
      |> Enum.sort()
      |> Stream.filter(fn module -> Atom.to_string(module) |> String.starts_with?("Elixir") end)
      |> Stream.flat_map(fn module ->
        [
          Atom.to_string(module)
          | IEx.Autocomplete.exports(module)
            |> Enum.map(fn {func, arity} ->
              {Atom.to_string(module), {Atom.to_string(func), to_string(arity)}}
            end)
        ]
      end)
      |> Stream.filter(fn
        {_, {"__" <> _, _}} -> false
        _ -> true
      end)
      |> Stream.map(fn
        {"Elixir." <> module, {func, arity}} -> "#{module}.#{func}/#{arity}"
        "Elixir." <> module -> module
      end)
      |> Enum.join("\n")

    quote do
      unquote(modules) |> IO.write()
    end
  end
end
