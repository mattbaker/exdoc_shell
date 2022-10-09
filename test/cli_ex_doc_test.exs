defmodule ExDocShellTest do
  use ExUnit.Case
  doctest ExDocShell

  test "greets the world" do
    assert ExDocShell.hello() == :world
  end
end
