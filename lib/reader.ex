defmodule Y4mReader do
@moduledoc """
Read properties and frames from a *.y4m file
"""
  defstruct [:file, :properties]
  alias Y4mReader.HeaderParser
  alias Y4mReader.FrameIterator

  @doc """
  Read file header from the IO `device` and return Y4mReader.
  """
  @spec read(atom | pid) :: %__MODULE__{} | {:invalid_header, binary()}
  def read(file) do
    header = IO.read(file, :line)

    case HeaderParser.parse(header) do
      {:invalid_header, details} -> {:invalid_header, details}
      {:ok, props} -> %__MODULE__{
        file: file,
        properties: props
      }
    end
  end

  defp plane_lengths(:C444, width, height),
    do: [
      width * height,
      width * height,
      width * height
    ]

  defp plane_lengths(:C420, width, height),
    do: [
      width * height,
      trunc(width * height / 2),
      trunc(width * height / 2)
    ]

  defp plane_lengths(_not_supported, _width, _height),
    # we only support C444, C420
    do: {:error, :unsupported_colorspace}

  @doc """
  Read the next frame.
  """
  @spec next_frame(%__MODULE__{}) :: :eof | list(binary()) | {:error, atom}
  def next_frame(%__MODULE__{properties: %{color_space: cs, width: w, height: h}} = dec) do
    [y_plane_len, u_plane_len, v_plane_len] =
      case plane_lengths(cs, w, h) do
        [y_len, u_len, v_len] -> [y_len, u_len, v_len]
        {:error, :unsupported_colorspace} -> {:error, :unsupported_colorspace}
      end

    # read six bytes and look for magic frame header
    case IO.binread(dec.file, 6) do
      "FRAME\n" ->
        # read the three color planes from the file
        y_plane = IO.binread(dec.file, y_plane_len)
        u_plane = IO.binread(dec.file, u_plane_len)
        v_plane = IO.binread(dec.file, v_plane_len)

        # convert them to lists
        [y_plane, u_plane, v_plane]

      :eof ->
        # end of file
        :eof

      {:error, reason} ->
        # error from binread
        {:error, reason}

      _not_FRAME ->
        # unexpected file format
        {:error, :parsing_error}
    end
  end

  @doc """
  Return iterator over all frames in this file stream.
  """
  @spec iter_frames(%__MODULE__{}) :: Enumerable.t()
  def iter_frames(%__MODULE__{} = dec) do
    FrameIterator.init(dec)
  end
end


defmodule Y4mReader.HeaderParser do
  @moduledoc """
  Parser to deserialize y4m file header.
  """

  # TODO: explore options to infer color_space from file length
  @default_values %{color_space: :C420}

  @doc """
  Deserialize first line in y4m file.
  """
  @spec parse(binary) :: {:ok, any()} | {:invalid_header, binary()}
  def parse(header_line) do
    case String.split(header_line) do
      ["YUV4MPEG2" | rest] ->
        case continue(rest, @default_values) do
          %{} = props -> {:ok, props}
          {:error, reason} -> {:invalid_header, reason}
        end

      _ ->
        {:invalid_header, "unexpected beginning of file"}
    end
  end

  defp continue([], props), do: props

  defp continue([<<"W", width::binary>> | t], props) do
    case Integer.parse(width) do
      {width, _} -> continue(t, Map.put(props, :width, width))
      :error -> {:error, "cannot parse width: #{width}"}
    end
  end

  defp continue([<<"H", height::binary>> | t], props) do
    case Integer.parse(height) do
      {height, _} -> continue(t, Map.put(props, :height, height))
      :error -> {:error, "cannot parse height: #{height}"}
    end
  end

  defp continue([<<"F", frame_rate::binary>> | t], props) do
    with [nom, den] <- String.split(frame_rate, ":"),
         [{nom, rest}, {den, rest}] <- Enum.map([nom, den], &Integer.parse/1) do
      continue(t, Map.put(props, :frame_rate, [nom, den]))
    else
      _ -> {:error, "cannot parse frame rate: #{frame_rate}"}
    end
  end

  defp continue([<<"I", interlacing::binary>> | t], props) do
    case interlacing do
      "p" -> continue(t, Map.put(props, :interlacing, :progressive))
      "t" -> continue(t, Map.put(props, :interlacing, :top_field_first))
      "b" -> continue(t, Map.put(props, :interlacing, :bottom_field_first))
      "m" -> continue(t, Map.put(props, :interlacing, :mixed))
      _ -> {:error, "unknown interlacing: #{interlacing}"}
    end
  end

  defp continue([<<"A", aspect_ratio::binary>> | t], props) do
    with [nom, den] <- String.split(aspect_ratio, ":"),
         [{nom, rest}, {den, rest}] <- Enum.map([nom, den], &Integer.parse/1) do
      continue(t, Map.put(props, :aspect_ratio, [nom, den]))
    else
      _ -> {:error, "cannot parse aspect ration: #{aspect_ratio}"}
    end
  end

  defp continue([<<"C", color_space::binary>> | t], props) do
    case color_space do
      "420jpeg" -> continue(t, Map.put(props, :color_space, :C420jpeg))
      "420paldv" -> continue(t, Map.put(props, :color_space, :C420paldv))
      "420" -> continue(t, Map.put(props, :color_space, :C420))
      "422" -> continue(t, Map.put(props, :color_space, :C422))
      "444" -> continue(t, Map.put(props, :color_space, :C444))
      "mono" -> continue(t, Map.put(props, :color_space, :Cmono))
      _ -> {:error, "unknown color space: #{color_space}"}
    end
  end

  defp continue([<<"X", param::binary>> | t], props) do
    [name, value] =
      param
      |> String.split("=")

    params = Map.get(props, :params, [])
    continue(t, Map.put(props, :params, [[name, value] | params]))
  end
end

defmodule Y4mReader.FrameIterator do
  defstruct [:decoder]

  @spec init(%Y4mReader{}) :: %Y4mReader.FrameIterator{ }
  def init(dec) do
    %__MODULE__{decoder: dec}
  end
end

defimpl Enumerable, for: Y4mReader.FrameIterator do
  alias Y4mReader.FrameIterator

  @spec slice(%Y4mReader.FrameIterator{}) :: none
  def slice(_iter) do
    raise RuntimeError, "FrameIterator only supports reduce"
  end

  @spec member?(%FrameIterator{}, any) :: none
  def member?(_iter, _e) do
    raise RuntimeError, "FrameIterator only supports reduce"
  end

  @spec count(%FrameIterator{}) :: none
  def count(_) do
    raise RuntimeError, "FrameIterator only supports reduce"
  end

  def reduce(%FrameIterator{}, {:halt, acc}, _fun) do
    {:halted, acc}
  end
  def reduce(%FrameIterator{} = iter, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(iter, &1, fun)}
  end
  def reduce(%FrameIterator{decoder: dec} = is, {:cont, acc}, fun) do
    case Y4mReader.next_frame(dec) do
      [y, u, v] -> reduce(is, fun.([y, u, v], acc), fun)
      :eof -> {:done, acc}
    end
  end
end
