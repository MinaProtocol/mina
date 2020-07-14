defmodule CodaValidation.MixProject do
  use Mix.Project

  def project do
    [
      app: :coda_validation,
      name: "CodaValidation",
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: true,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_add_deps: :app_tree,
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      docs: [
        main: "CodaValidation",
        extras: ["README.md"]
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {Coda.Application, []},
      extra_applications: [:sasl, :logger]
    ]
  end

  defp deps do
    [
      {:google_api_logging, "~> 0.28.0"},
      {:google_api_pub_sub, "~> 0.23.0"},
      {:goth, "~> 1.2.0"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.14.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.22", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.10", only: [:test]}
    ]
  end

  defp aliases do
    [
      test: "test --no-start",
      run: "run --no-halt",
      check: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "dialyzer",
        "credo"
      ]
    ]
  end
end
