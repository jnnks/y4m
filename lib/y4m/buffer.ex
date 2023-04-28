defmodule Y4m.Buffer do
  @moduledoc """
  Data buffer for fragmented y4m streams.
  Buffer will accept data and return either the properties or frames, once enough data is present.
  """
  use GenServer

  alias Y4m.FrameParser
  alias Y4m.HeaderParser

  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, [], opts)

  @doc """
  Push data into the buffer.
  """
  @spec push(atom | pid | {atom, any} | {:via, atom, any}, binary()) ::
          {:error, :need_more_data} | {:frames, [binary()]} | {:props, map()}
  def push(buffer, data), do: GenServer.call(buffer, {:push, data})

  defmodule State do
    defstruct collecting_header: true, buffer: "", frame_size: 0
  end

  @impl GenServer
  @spec init([]) :: {:ok, any}
  def init([]) do
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call({:push, data}, _from, state = %State{collecting_header: true}) do
    buffer = state.buffer <> data

    {reply, state} =
      case :binary.split(buffer, "\n") do
        [buffer] ->
          new_state = %State{state | buffer: buffer}
          {{:error, :need_more_data}, new_state}

        [header, rest] ->
          {:ok, props} = HeaderParser.parse(header)

          frame_size =
            FrameParser.plane_lengths(props.color_space, props.width, props.height)
            |> Enum.sum()

          new_state = %State{
            state
            | buffer: rest,
              collecting_header: false,
              frame_size: frame_size
          }

          {{:props, props}, new_state}
      end

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:push, data}, _from, state = %State{collecting_header: false}) do
    buffer = state.buffer <> data
    frames = split_frames(buffer, state.frame_size)

    if Enum.empty?(frames) do
      {:reply, {:error, :need_more_data}, %State{state | buffer: buffer}}
    else
      cutoff_index = length(frames) * (state.frame_size + 6)
      buffer = :binary.part(buffer, cutoff_index, byte_size(buffer) - cutoff_index)
      {:reply, {:frames, frames}, %State{state | buffer: buffer}}
    end
  end

  defp split_frames(buffer, frame_size) when byte_size(buffer) < frame_size + 6, do: []

  defp split_frames(buffer, frame_size) when byte_size(buffer) >= frame_size + 6 do
    <<"FRAME\n", buffer::binary>> = buffer
    <<frame::size(frame_size * 8), rest::binary>> = buffer

    [<<frame::size(frame_size * 8)>> | split_frames(rest, frame_size)]
  end
end
