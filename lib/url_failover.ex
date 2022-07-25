defmodule UrlFailover do
  @moduledoc """
  Documentation for `UrlFailover`.
  """

  use GenServer

  @check_interval Application.compile_env(:url_failover, :check_interval, :timer.seconds(30))

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    with {:ok, urls} when is_list(urls) <- Keyword.fetch(opts, :urls),
         true <- valid_list_if_urls?(urls) do
      send(self(), :check)
      :timer.send_interval(@check_interval, :check)

      {:ok, %{check_urls: urls}}
    else
      :error ->
        {:stop, :no_urls_provided}

      _ ->
        {:stop, :invalid_list_of_urls}
    end
  end

  @impl true
  def handle_info(:check, %{check_urls: _check_urls} = state) do
    {:noreply, state}
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
end
