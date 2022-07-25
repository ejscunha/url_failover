# Simple URL Failover

This is a simple library to periodically check if HTTP servers are healthy, given a list of URLs.
Periodically (defaults to 30 seconds), makes an HTTP GET request (concurrently) to each URL in the list, if it returns an HTTP status code in the range of 200 and 499 and within a given time (defaults to 10 seconds), the URL is considered healthy. If there is a change in health status of an URL, a message is sent to all subscribers to act accordingly.

It provides three functions:

 - `get_url` Returns a random healthy URL from the given list, if there is no healthy URL it returns an error tuple
 - `subscribe` Subscribes the calling process to URL health changes, whenever a URL health status changes a message is sent to all subscribers with the following format `{:url_health, <:healthy|:not_health>, <URL>}`.
 - `unsubscribe` Unsubscribes the calling process from URL health changes messages.

## Usage example

```elixir
iex> UrlFailover.start_link(urls: ["https://elixir-lang.org"])
{:ok, pid}
iex> UrlFailover.subscribe()
:ok
iex> flush()
{:url_health, :healthy, "https://elixir-lang.org"}
iex> UrlFailover.get_url()
{:ok, "https://elixir-lang.org"}
```

## Configuration

```elixir
config :url_failover,
  check_interval: :timer.seconds(10),
  check_timeout: :timer.seconds(10)
```

## Instalation

TODO
