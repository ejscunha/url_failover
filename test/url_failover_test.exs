defmodule UrlFailoverTest do
  use ExUnit.Case
  alias Plug.Conn

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

  describe "URL health check" do
    setup do
      bypass = Bypass.open()
      [bypass: bypass]
    end

    test "checks given URLs health check at start", %{test: test, bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "GET", "/path", fn conn ->
        send(test_pid, :checked)
        Conn.resp(conn, 200, "")
      end)

      url = "http://localhost:#{bypass.port}/path"

      start_supervised!({UrlFailover, urls: [url], name: test})

      assert_receive :checked
    end

    test "checks given URLs health check periodically", %{test: test, bypass: bypass} do
      test_pid = self()
      interval = Application.get_env(:url_failover, :check_interval)

      Bypass.expect(bypass, "GET", "/path", fn conn ->
        send(test_pid, :checked)
        Conn.resp(conn, 200, "")
      end)

      url = "http://localhost:#{bypass.port}/path"

      start_supervised!({UrlFailover, urls: [url], name: test})

      assert_receive :checked
      assert_receive :checked, interval + 10
    end

    test "marks healthy URLs with healthy check", %{test: test, bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "GET", "/path", fn conn ->
        send(test_pid, :checked)
        Conn.resp(conn, 200, "")
      end)

      url = "http://localhost:#{bypass.port}/path"

      pid = start_supervised!({UrlFailover, urls: [url], name: test})

      assert_receive :checked

      assert %{healthy_urls: [^url]} = :sys.get_state(pid)
    end

    test "does not mark unhealthy URLs with healthy check", %{test: test, bypass: bypass} do
      test_pid = self()

      Bypass.expect_once(bypass, "GET", "/path", fn conn ->
        send(test_pid, :checked)
        Conn.resp(conn, 500, "")
      end)

      url = "http://localhost:#{bypass.port}/path"

      pid = start_supervised!({UrlFailover, urls: [url], name: test})

      assert_receive :checked

      assert %{healthy_urls: []} = :sys.get_state(pid)
    end

    test "checks that fail due to timeout are considered unhealthy", %{test: test, bypass: bypass} do
      test_pid = self()
      timeout = Application.get_env(:url_failover, :check_timeout)

      Bypass.expect_once(bypass, "GET", "/path", fn conn ->
        Process.sleep(timeout + 10)
        send(test_pid, :checked)
        Conn.resp(conn, 200, "")
      end)

      url = "http://localhost:#{bypass.port}/path"

      pid = start_supervised!({UrlFailover, urls: [url], name: test})

      assert_receive :checked, timeout + 20

      assert %{healthy_urls: []} = :sys.get_state(pid)
    end
  end

  describe "get_url/1" do
    test "returns a random healthy URL", %{test: test} do
      bypass = Bypass.open()
      test_pid = self()

      Bypass.expect_once(bypass, "GET", "/path1", fn conn ->
        send(test_pid, :checked)
        Conn.resp(conn, 200, "")
      end)

      Bypass.expect_once(bypass, "GET", "/path2", fn conn ->
        send(test_pid, :checked)
        Conn.resp(conn, 200, "")
      end)

      urls = ["http://localhost:#{bypass.port}/path1", "http://localhost:#{bypass.port}/path2"]

      start_supervised!({UrlFailover, urls: urls, name: test})

      assert_receive :checked
      assert_receive :checked

      assert {:ok, url} = UrlFailover.get_url(test)
      assert url in urls
    end

    test "returns {:error, :no_healthy_url} if there are no healthy URLs", %{test: test} do
      start_supervised!({UrlFailover, urls: [], name: test})
      assert {:error, :no_healthy_url} = UrlFailover.get_url(test)
    end
  end
end
