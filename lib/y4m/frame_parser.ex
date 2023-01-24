defmodule Y4m.FrameParser do
  defp plane_lengths(:C444, width, height),
    do: [
      width * height,
      width * height,
      width * height
    ]

  defp plane_lengths(:C422, width, height),
    do: [
      width * height,
      trunc(width * height / 2),
      trunc(width * height / 2)
    ]

  defp plane_lengths(:C420MPEG2, width, height),
    do: plane_lengths(:C420, width, height)
  defp plane_lengths(:C420, width, height),
    do: [
      width * height,
      trunc(width * height / 4),
      trunc(width * height / 4)
    ]

  @doc """
  Read the next frame from the `file`.
  Frame length in bytes depends on `width`, `height` and `color_space`.
  """
  @spec next_frame(pid(), atom, integer(), integer()) :: :eof | list(binary()) | {:error, atom}
  def next_frame(file, color_space, width, height) do
    [y_len, u_len, v_len] = plane_lengths(color_space, width, height)

    # read six bytes and look for magic frame header
    case IO.binread(file, 6) do
      "FRAME\n" ->
        # read the three color planes from the file
        y_plane = IO.binread(file, y_len)
        u_plane = IO.binread(file, u_len)
        v_plane = IO.binread(file, v_len)
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
end
