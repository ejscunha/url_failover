defmodule UrlFailoverTest do
  use ExUnit.Case
  doctest UrlFailover

  test "greets the world" do
    assert UrlFailover.hello() == :world
  end
end
