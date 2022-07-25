defmodule UrlFailover.MixProject do
  use Mix.Project

  def project do
    [
      app: :url_failover,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_add_apps: [:ex_unit],
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end
end
