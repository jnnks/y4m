defmodule Y4mFrameLoop do
  defstruct [:file_path, :file, :reader]
  # @spec init(binary) :: %Y4mFrameLoop{
  @spec init(binary) :: {:error, atom} | %Y4mFrameLoop{}
  def init(file_path) do
    with {:ok, file} <- File.open(file_path),
         reader = Y4mReader.read(file) do
      %__MODULE__{file_path: file_path, file: file, reader: reader}
    end
  end

  def next(loop = %__MODULE__{file_path: path, file: file, reader: reader}) do
    case Y4mReader.next_frame(reader) do
      [y, u, v] -> {loop, [y, u, v]}

      :eof ->
        :ok = File.close(file)
        {:ok, file} = File.open(path)
        reader = Y4mReader.read(file)
        frame = Y4mReader.next_frame(reader)
        {%Y4mFrameLoop{reader: reader, file: file, file_path: path}, frame}
    end
  end
end

defimpl Enumerable, for: Y4mFrameLoop do
  def slice(_iter) do
    raise RuntimeError, "Y4mLoop only supports reduce"
  end

  def member?(_iter, _e) do
    raise RuntimeError, "Y4mLoop only supports reduce"
  end

  def count(_) do
    raise RuntimeError, "Y4mLoop only supports reduce"
  end

  def reduce(_loop, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  def reduce(loop, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(loop, &1, fun)}
  end

  def reduce(loop = %Y4mFrameLoop{}, {:cont, acc}, fun) do
    {loop, frame} = Y4mFrameLoop.next(loop)
    reduce(loop, fun.(frame, acc), fun)
  end
end
