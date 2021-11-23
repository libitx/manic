defmodule Manic.MixProject do
  use Mix.Project

  def project do
    [
      app: :manic,
      version: "0.1.0",
      elixir: "~> 1.11",
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
      {:bsv, "~> 2.0"},
      {:castore, "~> 0.1"},
      {:curvy, "~> 0.3"},
      {:ex_doc, "~> 0.26", only: :dev, runtime: false},
      {:jason, "~> 1.2"},
      {:mint, "~> 1.4"},
      {:recase, "~> 0.7"},
      {:tesla, "~> 1.4"}
    ]
  end
end
