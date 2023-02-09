defmodule Y4mTest do
  use ExUnit.Case

  doctest Y4m
  doctest Y4m.Stream
  doctest Y4m.Writer

  @tag :stream_yuv
  test "YUV444 Test" do
    {props, stream} = Y4m.stream("test/videos/test_C444.y4m")
    frames = Enum.to_list(stream)
    assert props == %{color_space: :C444, frame_rate: [5, 1], height: 32, width: 32}
    assert length(frames) == 25

    len_bytes =
      frames
      |> Enum.reduce(0, fn [_y, _u, _v] = frame, acc  ->
        acc + (Enum.map(frame, &byte_size/1) |> Enum.sum())
      end)
    assert len_bytes == (32 * 32 * 3) * 25
  end

  @tag :stream_yuv
  test "YUV422 Test" do
    {props, stream} = Y4m.stream("test/videos/test_C422.y4m")
    frames = Enum.to_list(stream)
    assert props == %{color_space: :C422, frame_rate: [5, 1], height: 32, width: 32}
    assert length(frames) == 25

    len_bytes =
      frames
      |> Enum.reduce(0, fn [_y, _u, _v] = frame, acc  ->
        acc + (Enum.map(frame, &byte_size/1) |> Enum.sum())
      end)
    assert len_bytes == (32 * 32 * 2) * 25
  end

  @tag :stream_yuv
  test "YUV420 Test" do
    {props, stream} = Y4m.stream("test/videos/test_C420.y4m")
    frames = Enum.to_list(stream)
    assert props == %{color_space: :C420, frame_rate: [5, 1], height: 32, width: 32}
    assert length(frames) == 25

    len_bytes =
      frames
      |> Enum.reduce(0, fn [_y, _u, _v] = frame, acc  ->
        acc + (Enum.map(frame, &byte_size/1) |> Enum.sum())
      end)
    assert len_bytes == (32 * 32 * 1.5) * 25
  end

  @tag :stream_yuv
  test "YUV400 Test" do
    {props, stream} = Y4m.stream("test/videos/test_Cmono.y4m")
    frames = Enum.to_list(stream)
    assert props == %{color_space: :Cmono, frame_rate: [5, 1], height: 32, width: 32}
    assert length(frames) == 25

    len_bytes =
      frames
      |> Enum.reduce(0, fn [_y, _u, _v] = frame, acc  ->
        acc + (Enum.map(frame, &byte_size/1) |> Enum.sum())
      end)
    assert len_bytes == (32 * 32) * 25
  end

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

    {props, _stream} = Y4m.stream(file_path)

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

    {props, stream} = Y4m.stream("test/videos/example.y4m")
    {:ok, writer} = Y4m.write("test/videos/example_inv.y4m", props)

    # invert frames
    in_frames = stream |> Enum.to_list()

    in_frames
    |> Enum.map(&invert_pixels.(&1))
    |> Y4m.append(writer)
    |> Y4m.Writer.close()

    {_props, stream} = Y4m.stream("test/videos/example_inv.y4m")
    actual_frames = stream |> Enum.to_list()
    assert length(in_frames) == length(actual_frames)
    assert in_frames |> Enum.map(&invert_pixels.(&1)) == actual_frames
  end
end
