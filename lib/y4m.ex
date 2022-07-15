defmodule Y4MDecoder do
  defstruct [:file, :properties]
  alias Y4MDecoder.HeaderParser
  alias Y4MDecoder.FrameIterator

  def open(file_path) do
    with {:ok, file} <- File.open(file_path),
         header <- IO.read(file, :line),
         properties <- HeaderParser.parse(header) do
      case properties do
        %{color_space: :C444} ->
          %__MODULE__{
            file: file,
            properties: properties
          }

        # we only support C444
        %{color_space: _not_c444} ->
          {:error, :unsupported_colorspace}

        # if no colorspace is listed
        %{} ->
          %__MODULE__{
            file: file,
            properties: properties
          }
      end
    end
  end

  def next_frame(%__MODULE__{properties: %{width: w, height: h}} = dec) do
    plane_len = w * h

    # read six bytes and look for magic frame header
    case IO.binread(dec.file, 6) do
      "FRAME\n" ->
        # read the three color planes from the file
        y_plane = IO.binread(dec.file, plane_len)
        u_plane = IO.binread(dec.file, plane_len)
        v_plane = IO.binread(dec.file, plane_len)

        # convert them to lists
        [y_plane, u_plane, v_plane] |> Enum.map(&:binary.bin_to_list/1)

      :eof ->
        :eof

      # error from binread
      {:error, reason} ->
        {:error, reason}
    end
  end

  def iter_frames(%__MODULE__{} = dec) do
    FrameIterator.init(dec)
  end
end

defmodule Y4MDecoder.FrameIterator do
  defstruct [:decoder]

  def init(%Y4MDecoder{} = dec) do
    %__MODULE__{decoder: dec}
  end
end

defimpl Enumerable, for: Y4MDecoder.FrameIterator do
  alias Y4MDecoder.FrameIterator

  def reduce(_stream, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  def reduce(%FrameIterator{} = is, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(is, &1, fun)}
  end

  def reduce(%FrameIterator{decoder: dec} = is, {:cont, acc}, fun) do
    case Y4MDecoder.next_frame(dec) do
      [y, u, v] -> reduce(is, fun.([y, u, v], acc), fun)
      :eof -> {:done, acc}
    end
  end
end

defmodule Y4MDecoder.HeaderParser do
  def parse(header_line) do
    case String.split(header_line) do
      ["YUV4MPEG2" | rest] -> continue(rest, %{})
      _ -> {:error, "file does not have expected header"}
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
