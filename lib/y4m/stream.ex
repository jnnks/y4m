defmodule Y4m.Stream do
  defstruct [:file, :props]

  # line: convert plane binaries to lists, before emitting them
  @type option() :: :line
  @type options() :: [option()] | []

  @doc """
  Initialize a Stream of y4m frames.
  The file header is read immediately, but frames are evaluated on demand.
  """
  @spec init(atom | pid, options()) :: {:error, atom} | {%{}, Enumerable.t()}
  def init(file, opts) do
    header = IO.read(file, :line)

    convert_bin_to_list = :list in opts

    case Y4m.HeaderParser.parse(header) do
      {:error, details} ->
        {:error, details}

      {:ok, props} ->
        stream =
          %__MODULE__{file: file, props: props}
          # easy convert to real stream
          |> Stream.map(fn f -> f end)

        stream =
          if convert_bin_to_list,
            do: Stream.map(stream, fn planes -> Enum.map(planes, &:binary.bin_to_list/1) end),
            else: stream

        {props, stream}
    end
  end
end

defimpl Enumerable, for: Y4m.Stream do
  def slice(_iter), do: raise(RuntimeError, "FrameIterator only supports reduce")
  def member?(_iter, _e), do: raise(RuntimeError, "FrameIterator only supports reduce")
  def count(_), do: raise(RuntimeError, "FrameIterator only supports reduce")

  def reduce(%Y4m.Stream{}, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  def reduce(%Y4m.Stream{} = iter, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(iter, &1, fun)}
  end

  def reduce(%Y4m.Stream{file: file, props: props} = is, {:cont, acc}, fun) do
    %{width: w, height: h, color_space: cs} = props

    case Y4m.FrameParser.next_frame(file, cs, w, h) do
      [y, u, v] ->
        reduce(is, fun.([y, u, v], acc), fun)

      :eof ->
        File.close(file)
        {:done, acc}

      {:error, :terminated} ->
        raise RuntimeError, "File Stream has been consumed entirely"
    end
  end
end
