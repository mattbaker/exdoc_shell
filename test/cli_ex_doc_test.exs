defmodule CliExDocTest do
  use ExUnit.Case
  doctest CliExDoc

  test "greets the world" do
    assert CliExDoc.hello() == :world
  end
end
