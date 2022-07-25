defmodule UrlFailoverTest do
  use ExUnit.Case

  describe "start_link/1" do
    test "defaults process name to UrlFailover" do
      pid = start_supervised!({UrlFailover, urls: []})
      assert GenServer.whereis(UrlFailover) == pid
    end

    test "accepts a name for the process", %{test: test} do
      pid = start_supervised!({UrlFailover, urls: [], name: test})
      assert GenServer.whereis(test) == pid
    end

    test "returns {:error, :no_urls_provided} if no URLs are given", %{test: test} do
      # using start_supervised/1 here to handle exit from star_link call which can make
      # the test fail, also start_supervised/1 changes the format of the returned error
      assert {:error, {:no_urls_provided, _}} = start_supervised({UrlFailover, name: test})
    end

    test "returns {:error, :invalid_list_of_urls} if at least one of the give URLs is invalid", %{
      test: test
    } do
      # using start_supervised/1 here to handle exit from star_link call which can make
      # the test fail, also start_supervised/1 changes the format of the returned error

      assert {:error, {:invalid_list_of_urls, _}} =
               start_supervised({UrlFailover, urls: [:invalid], name: test})

      assert {:error, {:invalid_list_of_urls, _}} =
               start_supervised({UrlFailover, urls: ["invalid"], name: test})

      assert {:error, {:invalid_list_of_urls, _}} =
               start_supervised({UrlFailover, urls: ["http"], name: test})

      assert {:error, {:invalid_list_of_urls, _}} =
               start_supervised({UrlFailover, urls: ["http://"], name: test})

      assert {:error, {:invalid_list_of_urls, _}} =
               start_supervised({UrlFailover, urls: ["ftp://www.google.com"], name: test})
    end

    test "accepts a list of valid URLs", %{test: test} do
      urls = [
        "https://www.google.com",
        "https://www.google.com:443",
        "http://localhost:8000",
        "http://localhost:8000/path",
        "http://user:pass@localhost:8000"
      ]

      assert {:ok, pid} = start_supervised({UrlFailover, urls: urls, name: test})
      assert is_pid(pid)
    end
  end
end
