defmodule Y4m.HeaderParser do
  @moduledoc """
  Parser to deserialize y4m file header according to the specification found here:
  https://wiki.multimedia.cx/index.php/YUV4MPEG2
  """

  # TODO: explore options to infer color_space from file length
  @default_values %{color_space: :C420}

  @doc """
  Deserialize first line in y4m file.
  """
  @spec parse(binary) :: {:ok, any()} | {:error, atom}
  def parse(header_line) do
    # split the header line into list of strings
    case String.split(header_line) do
      ["YUV4MPEG2" | rest] ->
        case continue(rest, @default_values) do
          %{} = props -> {:ok, props}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :missing_yuvmpeg2_header}
    end
  end

  defp continue([], props), do: props

  defp continue([<<"W", width::binary>> | t], props) do
    case Integer.parse(width) do
      {width, _} -> continue(t, Map.put(props, :width, width))
      :error -> {:error, :invalid_width}
    end
  end

  defp continue([<<"H", height::binary>> | t], props) do
    case Integer.parse(height) do
      {height, _} -> continue(t, Map.put(props, :height, height))
      :error -> {:error, :invalid_height}
    end
  end

  defp continue([<<"F", frame_rate::binary>> | t], props) do
    with [nom, den] <- String.split(frame_rate, ":"),
         [{nom, rest}, {den, rest}] <- Enum.map([nom, den], &Integer.parse/1) do
      continue(t, Map.put(props, :frame_rate, [nom, den]))
    else
      _ -> {:error, :invalid_frame_rate}
    end
  end

  defp continue([<<"I", interlacing::binary>> | t], props) do
    case interlacing do
      "p" -> continue(t, Map.put(props, :interlacing, :progressive))
      "t" -> continue(t, Map.put(props, :interlacing, :top_field_first))
      "b" -> continue(t, Map.put(props, :interlacing, :bottom_field_first))
      "m" -> continue(t, Map.put(props, :interlacing, :mixed))
      _ -> {:error, :invalid_interlacing}
    end
  end

  defp continue([<<"A", aspect_ratio::binary>> | t], props) do
    with [nom, den] <- String.split(aspect_ratio, ":"),
         [{nom, rest}, {den, rest}] <- Enum.map([nom, den], &Integer.parse/1) do
      continue(t, Map.put(props, :aspect_ratio, [nom, den]))
    else
      _ -> {:error, :invalid_aspect_ratio}
    end
  end

  defp continue([<<"C", color_space::binary>> | t], props) do
    case color_space |> String.downcase() do
      "420jpeg" -> {:error, :unsupported_color_space}
      "420paldv" -> {:error, :unsupported_color_space}
      "420mpeg2" -> continue(t, Map.put(props, :color_space, :C420MPEG2))
      "420" -> continue(t, Map.put(props, :color_space, :C420))
      "422" -> {:error, :unsupported_color_space}
      "444" -> continue(t, Map.put(props, :color_space, :C444))
      "mono" -> {:error, :unsupported_color_space}
      _ -> {:error, :invalid_color_space}
    end
  end

  defp continue([<<"X", param::binary>> | t], props) do
    case param |> String.split("=") do
      [name, value] ->
        params = Map.get(props, :params, [])
        continue(t, Map.put(props, :params, params ++ [[name, value]]))

      _ ->
        # ignore invalid property
        continue(t, props)
    end
  end
end
