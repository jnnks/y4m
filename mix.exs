defmodule Y4m.MixProject do
  use Mix.Project

  def project do
    [
      app: :y4m,
      version: "0.3.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application, do: []

  defp deps,
    do: [
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:gen_stage, "~> 1.1.2", only: :test, runtime: false},
      {:nx, "~> 0.1", only: :test, runtime: false}
    ]

  defp description() do
    "Collection of convenience functions to read *.y4m files."
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs CHANGELOG.md README.md LICENSE*),
      licenses: ["0BSD"],
      links: %{"GitHub" => "https://github.com/jnnks/y4m"}
    ]
  end
end
