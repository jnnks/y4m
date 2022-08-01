defmodule Y4mTest do
  use ExUnit.Case

  doctest Y4m
  doctest Y4m.Stream
  doctest Y4m.Writer

  @tag :stream
  test "Read all frames from stream" do
    {file_path, frames} = TestHelper.write_test_file(10)
    {_props, stream} = Y4m.stream(file_path)

    actual_frames = stream |> Enum.to_list()
    assert 10 == length(actual_frames)
    assert frames == actual_frames
  end

  @tag :stream
  test "Make stream overflow" do
    {file_path, frames} = TestHelper.write_test_file(10)
    {_props, stream} = Y4m.stream(file_path)

    # take more frames than available
    # --> no error first time, like stream
    actual_frames = stream |> Enum.take(12)
    assert 10 == length(actual_frames)
    assert frames == actual_frames

    # overflow stream
    # --> will raise
    assert_raise RuntimeError, ~r/^File Stream has been consumed entirely/, fn ->
      stream |> Enum.take(1)
    end
  end

  @tag :write
  test "Write props" do
    props = %{
      aspect_ratio: [1, 1],
      color_space: :C444,
      frame_rate: [2, 1],
      height: 288,
      interlacing: :progressive,
      params: [["COLORRANGE", "LIMITED"], ["YSCSS", "444"]],
      width: 512
    }

    Y4m.write("/tmp/test_file.y4m", props)
    {actual_props, stream} = Y4m.stream("/tmp/test_file.y4m")

    assert props == actual_props
    assert 0 == stream |> Enum.to_list() |> length()
  end

  @tag :write
  test "Write 10 y4m frames" do
    {frames, _binary} = TestHelper.get_test_frames(10, {2, 3})
    props = %{width: 2, height: 3, frame_rate: [2, 1], color_space: :C444}

    {:ok, writer} = Y4m.write("/tmp/test_file.y4m", props)
    frames |> Y4m.append(writer)
    Y4m.Writer.close(writer)

    {_props, stream} = Y4m.stream("/tmp/test_file.y4m")
    actual_frames = stream |> Enum.to_list()
    assert 10 == length(actual_frames)
    assert frames == actual_frames
  end

  @tag :this_one
  test "Copy y4m file" do
    {file_path, frames} = TestHelper.write_test_file(10, {2, 3})

    {props, stream} = Y4m.stream(file_path)

    {:ok, writer} = Y4m.write("/tmp/test_file2.y4m", props)

    frames
    |> Y4m.append(writer)
    |> Y4m.Writer.close()

    # files should have equal size
    assert File.stat!(file_path).size == File.stat!("/tmp/test_file2.y4m").size
    assert File.read!(file_path) == File.read!("/tmp/test_file2.y4m")
  end

  test "Invert pixels of y4m file" do
    invert_pixels = fn [y, u, v] ->
      [y, u, v]
      |> Enum.map(fn bin ->
        for <<i::8 <- bin>>, into: "", do: <<255 - i>>
      end)
    end

    {props, stream} = Y4m.stream("test/example.y4m")
    {:ok, writer} = Y4m.write("test/example_inv.y4m", props)

    # invert frames
    in_frames = stream |> Enum.to_list()

    in_frames
    |> Enum.map(&invert_pixels.(&1))
    |> Y4m.append(writer)
    |> Y4m.Writer.close()

    {props, stream} = Y4m.stream("test/example_inv.y4m")
    actual_frames = stream |> Enum.to_list()
    assert length(in_frames) == length(actual_frames)
    assert in_frames |> Enum.map(&invert_pixels.(&1)) == actual_frames
  end
end
