defmodule Y4mTest do
  use ExUnit.Case
  doctest Y4mReader

  test "read y4m header" do
    {:ok, file} =
      StringIO.open("YUV4MPEG2 W512 H288 F2:1 Ip A1:1 C444 XYSCSS=444 XCOLORRANGE=LIMITED")

    %Y4mReader{properties: props} = Y4mReader.read(file)

    assert props == %{
             aspect_ratio: [1, 1],
             color_space: :C444,
             frame_rate: [2, 1],
             height: 288,
             interlacing: :progressive,
             params: [["COLORRANGE", "LIMITED"], ["YSCSS", "444"]],
             width: 512
           }
  end

  test "read y4m header u16 width" do
    1..16
    |> Enum.map(fn exp ->
      w = :math.pow(2, exp)
      {:ok, f} = StringIO.open("YUV4MPEG2 W#{w} H1 F1:1")
      %Y4mReader{properties: props} = Y4mReader.read(f)
      assert w == props.width
    end)
  end

  test "read y4m header u16 height" do
    1..16
    |> Enum.map(fn exp ->
      h = :math.pow(2, exp)
      {:ok, f} = StringIO.open("YUV4MPEG2 W1 H#{h} F1:1")
      %Y4mReader{properties: props} = Y4mReader.read(f)
      assert h == props.height
    end)
  end

  test "read y4m header frame rate" do
    1..16
    |> Enum.map(fn nom ->
      1..16
      |> Enum.map(fn den ->
        {:ok, f} = StringIO.open("YUV4MPEG2 W1 H1 F#{nom}:#{den}")
        %Y4mReader{properties: props} = Y4mReader.read(f)
        assert [nom, den] == props.frame_rate
      end)
    end)
  end

  test "read y4m header interlacing" do
    modes = %{
      p: :progressive,
      t: :top_field_first,
      b: :bottom_field_first,
      m: :mixed
    }

    for {name, mode} <- modes do
      {:ok, file} = StringIO.open("YUV4MPEG2 W1 H1 F1:1 I#{name}")
      %Y4mReader{properties: props} = Y4mReader.read(file)
      assert mode == props.interlacing
    end
  end

  test "read y4m header aspect ratio" do
    1..16
    |> Enum.map(fn nom ->
      1..16
      |> Enum.map(fn den ->
        {:ok, f} = StringIO.open("YUV4MPEG2 W1 H1 A#{nom}:#{den}")
        %Y4mReader{properties: props} = Y4mReader.read(f)
        assert [nom, den] == props.aspect_ratio
      end)
    end)
  end

  test "read y4m header color space" do
    color_spaces = [
      :C420jpeg,
      :C420paldv,
      :C420,
      :C422,
      :C444,
      :Cmono
    ]

    for cs <- color_spaces do
      {:ok, f} = StringIO.open("YUV4MPEG2 W1 H1 #{cs}")
      %Y4mReader{properties: props} = Y4mReader.read(f)
      assert cs == props.color_space
    end
  end

  test "iter y4m frames" do
    # single YUV444 pixel
    pixel = <<255::size(8), 255::size(8), 255::size(8)>>

    # build 10 frames of 2x1 pixels
    frames =
      1..10
      |> Enum.map(fn _f ->
        <<"FRAME\n", pixel::binary, pixel::binary>>
      end)
      |> Enum.reduce(<<>>, fn e, acc -> acc <> e end)

    # build iter and take more frames than should be present
    {:ok, file} = StringIO.open("YUV4MPEG2 W2 H1 F1:1 C444\n" <> frames)

    read_frames =
      Y4mReader.read(file)
      |> Y4mReader.iter_frames()
      |> Enum.map(fn [y, u, v] -> [y, u, v] |> Enum.map(&:binary.bin_to_list/1) end)
      |> Enum.take(11)

    assert 10 == length(read_frames)
    assert Enum.all?(read_frames, fn f -> f == [[255, 255], [255, 255], [255, 255]] end)
  end

  test "iter y4m iter frames nx" do
    # single YUV444 pixel
    pixel = <<255::size(8), 255::size(8), 255::size(8)>>

    # build 10 frames of 2x1 pixels
    frames =
      1..10
      |> Enum.map(fn _f ->
        <<"FRAME\n", pixel::binary, pixel::binary>>
      end)
      |> Enum.reduce(<<>>, fn e, acc -> acc <> e end)

    # build iter and take more frames than should be present
    {:ok, file} = StringIO.open("YUV4MPEG2 W2 H1 F1:1 C444\n" <> frames)

    read_frames =
      Y4mReader.read(file)
      |> Y4mReader.iter_frames()
      |> Enum.map(fn [y, u, v] ->
        Nx.stack([
          Nx.from_binary(y, {:u, 8}),
          Nx.from_binary(u, {:u, 8}),
          Nx.from_binary(v, {:u, 8})
        ])
      end)

    assert 10 == length(read_frames)
  end

  test "loop y4m" do
    # build 10 frames of 2x1 pixels into test file
    frames =
      1..10
      |> Enum.map(fn i ->
        pixel = <<i::size(8), i::size(8), i::size(8)>>
        <<"FRAME\n", pixel::binary, pixel::binary>>
      end)
      |> Enum.reduce(<<>>, fn e, acc -> acc <> e end)

    File.write("/tmp/test_file.y4m", "YUV4MPEG2 W2 H1 F1:1 C444\n" <> frames)

    # take more frames than in file
    loop = Y4m.loop("/tmp/test_file.y4m")
    frames = Enum.take(loop, 12)
    assert 12 == length(frames)

    # take first frame and first frame of restarted stream
    loop = Y4m.loop("/tmp/test_file.y4m")
    assert [[<<1, 1>>, <<1, 1>>, <<1, 1>>]] == Enum.take(loop, 1)
    assert [<<1, 1>>, <<1, 1>>, <<1, 1>>] == Enum.take(loop, 10) |> Enum.at(9)
  end
end
