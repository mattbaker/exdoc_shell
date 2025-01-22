defmodule ExDocShell.Macros do
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

    mfas_with_docs =
      Enum.reduce(modules, MapSet.new(), fn module, set ->
        MapSet.union(set, visibilities(module))
      end)

    mfas =
      modules
      |> Stream.filter(fn module -> Atom.to_string(module) |> String.starts_with?("Elixir") end)
      |> Stream.flat_map(fn module ->
        [
          Atom.to_string(module)
          | exports(module, mfas_with_docs) ++ callbacks(module, mfas_with_docs)
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
      unquote(mfas) |> IO.write()
    end
  end

  defp exports(mod, mfas_with_docs) do
    IEx.Autocomplete.exports(mod)
    |> Enum.filter(fn {func, arity} ->
      MapSet.member?(mfas_with_docs, {mod, func, arity})
    end)
    |> Enum.map(fn {func, arity} ->
      {Atom.to_string(mod), {Atom.to_string(func), to_string(arity)}}
    end)
  end

  defp callbacks(mod, mfas_with_docs) do
    case Code.Typespec.fetch_callbacks(mod) do
      {:ok, callbacks} ->
        for {name_arity, _} <- callbacks do
          {_kind, name, arity} = IEx.Introspection.translate_callback_name_arity(name_arity)

          {name, arity}
        end

      :error ->
        []
    end
    |> Enum.filter(fn {cb, arity} ->
      MapSet.member?(mfas_with_docs, {mod, cb, arity})
    end)
    |> Enum.map(fn {cb, arity} ->
      {Atom.to_string(mod), {Atom.to_string(cb), to_string(arity)}}
    end)
  end

  defp visibilities(mod) do
    case Code.fetch_docs(mod) do
      {:docs_v1, _, _, _, _, _, docs} ->
        for {{kind, func, arity}, _, _, doc, _} <- docs,
            kind in [:macro, :function, :callback] and doc != :hidden do
          {mod, func, arity}
        end

      {:error, _} ->
        []
    end
    |> MapSet.new()
  end
end
