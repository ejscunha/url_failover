defmodule UrlFailover do
  @moduledoc """
  Documentation for `UrlFailover`.
  """

  use GenServer

  @check_interval Application.compile_env(:url_failover, :check_interval, :timer.seconds(30))
  @check_timeout Application.compile_env(:url_failover, :check_timeout, :timer.seconds(10))

  @type option :: {:name, GenServer.name()} | {:urls, [String.t()]}
  @type options :: [option()]

  @doc """
  Starts a GenServer that will periodically check a given list of URLs if they are
  healthy. A name can be given to the started GenServer, if none given it will
  default to UrlFailover.
  """
  @spec start_link(options) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns an ok tuple with a random healthy URL.

  iex> UrlFailover.get_url()
  {:ok, "https://elixir-lang.org"}

  iex> UrlFailover.get_url(MyUrlFailover)
  {:ok, "https://elixir-lang.org"}

  If there are not healthy URLs available it returns {:error, :no_healthy_url}.

  iex> UrlFailover.get_url()
  {:error, :no_healthy_url}
  """
  @spec get_url(GenServer.name()) :: {:ok, String.t()} | {:error, :no_healthy_url}
  def get_url(server \\ __MODULE__) do
    GenServer.call(server, :get_url)
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
        _, acc -> acc
      end)

    {:noreply, Map.put(state, :healthy_urls, healthy_urls)}
  end

  @impl true
  def handle_call(:get_url, _from, %{healthy_urls: healthy_urls} = state) do
    res =
      case healthy_urls do
        [] -> {:error, :no_healthy_url}
        _ -> {:ok, Enum.random(healthy_urls)}
      end

    {:reply, res, state}
  end

  defp valid_list_if_urls?(urls) do
    Enum.all?(urls, &valid_url?/1)
  end

  defp valid_url?(url) when is_binary(url), do: url |> URI.parse() |> valid_uri?()
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
