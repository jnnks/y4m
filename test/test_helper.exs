ExUnit.start()

defmodule TestHelper do
  def write_test_file(num_frames, dim \\ {2, 1}) do
    {w, h} = dim
    # build 10 frames of 2x1 pixels into test file
    frames =
      0..(num_frames - 1)
      |> Enum.map(fn i ->
        pixel = <<i::size(8), i::size(8), i::size(8)>>
        "FRAME\n" <> for _ <- 1..(w * h), into: "", do: pixel
      end)
      |> Enum.reduce(<<>>, fn e, acc -> acc <> e end)

    file_path = "/tmp/test_file.y4m"
    :ok = File.write(file_path, "YUV4MPEG2 W#{w} H#{h} F1:1 C444\n" <> frames)

    file_path
  end
end
