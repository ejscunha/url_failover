defmodule UrlFailover do
  @moduledoc """
  Documentation for `UrlFailover`.
  """

  use GenServer

  @check_interval Application.compile_env(:url_failover, :check_interval, :timer.seconds(30))
  @check_timeout Application.compile_env(:url_failover, :check_timeout, :timer.seconds(10))

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    with {:ok, urls} when is_list(urls) <- Keyword.fetch(opts, :urls),
         true <- valid_list_if_urls?(urls) do
      Process.flag(:trap_exit, true)

      send(self(), :check)
      :timer.send_interval(@check_interval, :check)

      {:ok, %{check_urls: urls, healthy_urls: []}}
    else
      :error ->
        {:stop, :no_urls_provided}

      _ ->
        {:stop, :invalid_list_of_urls}
    end
  end

  @impl true
  def handle_info(:check, %{check_urls: check_urls} = state) do
    healthy_urls =
      check_urls
      |> Task.async_stream(&check_url/1,
        ordered: false,
        timeout: @check_timeout,
        on_timeout: :kill_task
      )
      |> Enum.reduce([], fn
        {:ok, {:healthy, url}}, acc -> [url | acc]
        _, acc -> IO.inspect(acc)
      end)

    {:noreply, Map.put(state, :healthy_urls, healthy_urls)}
  end

  defp valid_list_if_urls?(urls) do
    Enum.all?(urls, &valid_url?/1)
  end

  defp valid_url?(url) when is_binary(url), do: url |> URI.parse() |> valid_uri?()
  defp valid_url?(url) when is_struct(url, URI), do: valid_uri?(url)
  defp valid_url?(_url), do: false

  defp valid_uri?(%URI{
         scheme: scheme,
         host: host,
         port: port
       })
       when scheme in ["http", "https"] and byte_size(host) > 0 and is_integer(port),
       do: true

  defp valid_uri?(_uri), do: false

  defp check_url(url) do
    charlist_url = to_charlist(url)

    case :httpc.request(charlist_url) do
      {:ok, {{_, status, _}, _, _}} when status in 200..499 -> {:healthy, url}
      _ -> {:not_healthy, url}
    end
  end
end
