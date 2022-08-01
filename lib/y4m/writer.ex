defmodule Y4m.Writer do
  defstruct [:file_path, :file, :props]
  def init(file_path, props) do
    file = File.open!(file_path, [:write])
    header = "YUV4MPEG2 " <> format_props(props) <> "\n"
    IO.binwrite(file, header)

    {:ok, %__MODULE__{file_path: file_path, file: file, props: props}}
  end

  def append(frames, %Y4m.Writer{file: file} = writer) do
    for [y_plane, u_plane, v_plane] <- frames do
      IO.binwrite(file, "FRAME\n")
      IO.binwrite(file, y_plane)
      IO.binwrite(file, u_plane)
      IO.binwrite(file, v_plane)
    end

    writer
  end

  def close(%Y4m.Writer{file: file}), do: File.close(file)

  defp format_props(props) do
    for {k, v} <- props do
      case {k, v} do
        {:width, val} -> "W#{val}"
        {:height, val} -> "H#{val}"
        {:frame_rate, [nom, den]} -> "F#{nom}:#{den}"
        {:aspect_ratio, [nom, den]} -> "A#{nom}:#{den}"
        {:color_space, cs} -> "#{cs}"
        {:interlacing, :progressive} -> "Ip"
        {:interlacing, :top_field_first} -> "It"
        {:interlacing, :bottom_field_first} -> "Ib"
        {:interlacing, :mixed} -> "Im"
        {:params, params} -> params
          |> Enum.map(fn [k, v] -> "X#{k}=#{v}" end)
          |> Enum.sort()
          |> Enum.join(" ")
      end
    end
    |> Enum.join(" ")
  end
end
