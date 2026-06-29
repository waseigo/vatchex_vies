defmodule VatchexVies.MixProject do
  use Mix.Project

  def project do
    [
      app: :vatchex_vies,
      version: "1.0.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "VatchexVies",
      source_url: "https://github.com/waseigo/vatchex_vies",
      homepage_url: "https://overbring.com/software/vatchex_vies/",
      docs: docs(),
      test_coverage: [summary: [threshold: 80]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Client for the EU VIES REST API (VAT number validation and company information lookup).
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*", "llms.txt"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/waseigo/vatchex_vies"}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:cachex, "~> 4.1", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.4", only: :test, runtime: false},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "VatchexVies",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_extras: [
        "README": ~r/README\.md/i,
        "Changelog": ~r/CHANGELOG\.md/i
      ]
    ]
  end
end
