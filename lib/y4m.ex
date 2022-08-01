defmodule Y4m do
  @moduledoc """
  Module for working with uncompressed frames of YCbCr videos.

  Only a subset of color spaces are supported (`C420`, `C444`), all others (`C420jpeg`, `C420paldv`, `C422`, `Cmono`) are missing.

  ### Open file and count frames in file
  `Y4m.stream` returns a tuple of metadata and a lazy stream.

      iex> {props, stream} = Y4m.stream("test/example.y4m")
      iex> props
      %{aspect_ratio: [0, 0], color_space: :C420, frame_rate: [25, 1], height: 288, interlacing: :progressive, width: 384}
      # get number of frames
      iex> stream |> Enum.to_list() |> length()
      51


  ### Using the Stream
  The metadata dictionary contains information about the resolution, color space
  and framerate as specified by the file header.

  The stream is read directly from file. That means that the streams state is implicitly
  handled by the file handle. When taking a frame from the stream, the stream will continue
  with the next frame in the file. This may lead to confusion as a hidden shared state is involved.
  Each frame is a list of binaries.

      iex> {_props, stream} = Y4m.stream("test/example.y4m")
      iex> [<<_y::binary>>, <<_u::binary>>, <<_v::binary>>] = Enum.at(stream, 0)
      iex> # frames do not match because of shared state
      iex> Enum.at(stream, 0) != Enum.at(stream, 0)
      true


  ### Looping a file
  Sometimes it's useful to loop a video in file. This can be done using GenServer to explicitly
  capture the frame streams state and to reopen the file as needed:

      iex> defmodule Y4mLoop do
      ...>   use GenServer
      ...>
      ...>   def start_link(file_path), do: GenServer.start_link(__MODULE__, file_path)
      ...>   def next(loop), do: GenServer.call(loop, :next)
      ...>   def properties(loop), do: GenServer.call(loop, :properties)
      ...>
      ...>   @impl true
      ...>   def init(file_path) do
      ...>     {props, stream} = Y4m.stream(file_path)
      ...>     {:ok, {file_path, props, stream}}
      ...>   end
      ...>
      ...>   @impl true
      ...>   def handle_call(:next, _from, {file_path, props, stream}) do
      ...>     case stream |> Enum.take(1) do
      ...>       [frame] ->
      ...>         {:reply, frame, {file_path, props, stream}}
      ...>
      ...>       [] ->
      ...>         # reopen video file
      ...>         {props, stream} = Y4m.stream(file_path)
      ...>         [frame] = stream |> Enum.take(1)
      ...>         {:reply, frame, {file_path, props, stream}}
      ...>     end
      ...>   end
      ...>
      ...>   @impl true
      ...>   def handle_call(:properties, _from, {file_path, props, stream}) do
      ...>     {:reply, props, {file_path, props, stream}}
      ...>   end
      ...> end
      ...>
      iex> # load file with fewer than 420 frames
      iex> {:ok, loop} = Y4mLoop.start_link("test/example.y4m")
      iex> 1..420 |> Enum.map(fn _i -> Y4mLoop.next(loop) end)
  """

  @doc ~S"""
  Reads y4m frames from a file on disk.
  Returns parsed file header and lazy stream across all frames in file.

  ### Examples
      iex> {:ok, file} = File.open("test/example.y4m")
      iex> {_props, stream} = Y4m.stream(file)
      iex> stream |> Enum.take(10)
  """
  @spec stream(binary | pid) :: {%{}, %Y4m.Stream{}} | {:error, atom}
  def stream(file) when is_pid(file), do: Y4m.Stream.init(file)
  def stream(file_path) when is_binary(file_path), do: File.open!(file_path) |> Y4m.Stream.init()

  def write(file_path, props, frames \\ [])

  def write(file_path, props, frames) when length(frames) == 0,
    do: Y4m.Writer.init(file_path, props)

  def write(file_path, props, frames) when length(frames) > 0 do
    {:ok, writer} = Y4m.Writer.init(file_path, props)
    Y4m.append(frames, writer)
  end

  def append(frames, writer), do: Y4m.Writer.append(frames, writer)
end
