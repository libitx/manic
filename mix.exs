defmodule Manic.MixProject do
  use Mix.Project

  def project do
    [
      app: :manic,
      version: "0.0.4",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Manic",
      description: "Manic is an Elixir client for interfacing with Bitcoin miner APIs.",
      source_url: "https://github.com/libitx/manic",
      docs: [
        main: "Manic",
        groups_for_modules: [
          "Internal": [
            Manic.JSONEnvelope,
            Manic.Miner,
            Manic.Multi
          ]
        ]
      ],
      package: [
        name: "manic",
        files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md),
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/libitx/manic"
        }
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bsv, "~> 0.2"},
      {:castore, "~> 0.1"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:jason, "~> 1.2"},
      {:mint, "~> 1.0"},
      {:recase, "~> 0.6"},
      {:tesla, "~> 1.3"}
    ]
  end
end
