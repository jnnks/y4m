ExUnit.start()

defmodule TestHelper do

  def get_test_frames(num_frames, {w, h}) do

    # build 10 frames of 2x1 pixels into test file
    frames =
      0..(num_frames - 1)
      |> Enum.map(fn i ->
        # pixel = <<, i::size(8), i::size(8)>>
        plane = for _ <- 1..(w * h), into: "", do: <<i::size(8)>>
        [plane, plane, plane]
      end)

    binary = frames
      |> Enum.reduce(<<>>, fn [y, u, v], acc -> acc <> "FRAME\n" <> y <> u <> v end)

    {frames, binary}
  end

  def write_test_file(num_frames, {w, h} \\ {2, 1}) do
    {frames, binary} = get_test_frames(num_frames, {w, h})
    file_path = "/tmp/test_file.y4m"
    :ok = File.write(file_path, "YUV4MPEG2 C444 F1:1 H#{h} W#{w}\n" <> binary)

    {file_path, frames}
  end
end
