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

  def reduce(l = %Y4mFrameLoop{reader: reader, file_path: path}, {:cont, acc}, fun) do
    case Y4mReader.next_frame(reader) do
      [y, u, v] ->
        reduce(l, fun.([y, u, v], acc), fun)

      :eof ->
        :ok = File.close(reader.file)
        {:ok, file} = File.open(path)
        reader = Y4mReader.read(file)
        frame = Y4mReader.next_frame(reader)
        reduce(%Y4mFrameLoop{reader: reader, file: file, file_path: path}, fun.(frame, acc), fun)
    end
  end
end
