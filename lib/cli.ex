defmodule Elchemy.Cli do
  @help """
  Available commands
      new <PROJECT_NAME>
          Start a new project

      init
          Add Elchemy to an existing project

      compile [INPUT_DIR] [OUTPUT_DIR] [--unsafe]
          Compile Elchemy source code

      clean
          Remove temporary files

  Options
      --help, -h Include a rainbow
      --version, -v Print Elchemy's version
      --verbose

  """

  def main(args \\ []) do
    {opts, arg, _} = parse_options(args)

    IO.puts("Using elchemy v#{version()}\n")

    handle(arg)

    if opts[:help] do
      help()
    end

    if opts[:version] do
      version()
    end
  end

  def handle([]), do: help()

  def handle(["new" | dir]) do
    IO.puts("new")

    # mix new $2
    # File.cd ()
    # handle(["init"]
  end

  def handle(["init"]), do: handle(["init", File.cwd!])

  def handle(["init", source_dir | _]) do
    if File.exists?("./mix.exs") do
      vsn = version()

      IO.puts("Getting latest version of elchemy")

      System.cmd("mix", [
        "archive.install",
        "https://github.com/wende/elchemy/releases/download/#{vsn}/elchemy-#{vsn}.ez",
        "--force"
      ])

      create_directory("elm")
      create_directory("test")

      IO.puts("Adding basic project files")

      [
        {"#{source_dir}/templates/elm-package.json", "./elm-package.json"},
        {"#{source_dir}/templates/elchemy.exs", "./elchemy.exs"},
        {"#{source_dir}/templates/Hello.elm", "./elm/Hello.elm"},
        {"#{source_dir}/templates/elchemy_test.exs", "./test/elchemy_test.exs"}
      ]
      |> Enum.each(&copy_file/1)

      IO.puts("Adding entires to .gitignore")
      File.write(".gitignore", "\nelm-deps\nelm-stuff", [:append])

      IO.puts("""

      Elchemy #{vsn} initialized. Make sure to add:

          |> Code.eval_file(\"elchemy.exs\").init

      to your mix.exs file as the last line of the project() function.
      This pipes the project keyword list to the elchemy init function to configure some additional values.
      Then run `mix test` to check if everything went fine.

      """)
    else
      IO.write(:stderr, "ERROR: No elixir project found. Make sure to run init in a project")
    end
  end

  def handle(["clean" | _]) do
    IO.puts("clean")
  end

  def handle(["compile" | _]) do
    IO.puts("compile")
  end

  def help(), do: IO.puts(@help)

  defp create_directory(path) do
    unless File.exists?(path) do
      IO.puts("* creating #{path}")
      File.mkdir(path)
    end
  end

  defp copy_file({src, dest}) do
    File.cp!(src, dest, fn _, _ -> false end)
  end

  defp version() do
    {:ok, vsn} = :application.get_key(:elchemy, :vsn)
    List.to_string(vsn)
  end

  defp parse_options(args) do
    OptionParser.parse(
      args,
      switches: [help: :boolean, version: :boolean, verbose: :boolean],
      aliases: [h: :help, v: :version]
    )
  end
end
