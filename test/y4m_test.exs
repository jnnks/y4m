defmodule Y4mTest do
  use ExUnit.Case
  doctest Y4m
  # doctest Y4m.Loop

  test "read y4m header" do
    {:ok, file} =
      StringIO.open("YUV4MPEG2 W512 H288 F2:1 Ip A1:1 C444 XYSCSS=444 XCOLORRANGE=LIMITED")

    {props, _stream} = Y4m.stream(file)

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

  test "read y4m header width" do
    1..16
    |> Enum.map(fn exp ->
      w = :math.pow(2, exp)
      {:ok, f} = StringIO.open("YUV4MPEG2 W#{w} H1 F1:1")
      {props, _stream} = Y4m.stream(f)
      assert w == props.width
    end)

    {:ok, f} = StringIO.open("YUV4MPEG2 Wxxx H1 F1:1")
    assert {:error, :invalid_width} == Y4m.stream(f)
  end

  test "read y4m header height" do
    1..16
    |> Enum.map(fn exp ->
      h = :math.pow(2, exp)
      {:ok, file} = StringIO.open("YUV4MPEG2 W1 H#{h} F1:1")
      {props, _stream} = Y4m.stream(file)
      assert h == props.height
    end)

    {:ok, file} = StringIO.open("YUV4MPEG2 W1 Hxxx F1:1")
    assert {:error, :invalid_height} == Y4m.stream(file)
  end

  test "read y4m header frame rate" do
    1..16
    |> Enum.map(fn nom ->
      1..16
      |> Enum.map(fn den ->
        {:ok, file} = StringIO.open("YUV4MPEG2 W1 H1 F#{nom}:#{den}")
        {props, _stream} = Y4m.stream(file)
        assert [nom, den] == props.frame_rate
      end)
    end)

    {:ok, file} = StringIO.open("YUV4MPEG2 W1 H1 Fx:1")
    assert {:error, :invalid_frame_rate} == Y4m.stream(file)

    {:ok, file} = StringIO.open("YUV4MPEG2 W1 H1 F1:x")
    assert {:error, :invalid_frame_rate} == Y4m.stream(file)

    {:ok, file} = StringIO.open("YUV4MPEG2 W1 H1 F1?1")
    assert {:error, :invalid_frame_rate} == Y4m.stream(file)
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
      {props, _stream} = Y4m.stream(file)
      assert mode == props.interlacing
    end

    {:ok, file} = StringIO.open("YUV4MPEG2 W1 H1 F1:1 Ix")
    assert {:error, :invalid_interlacing} == Y4m.stream(file)
  end

  test "read y4m header aspect ratio" do
    1..16
    |> Enum.map(fn nom ->
      1..16
      |> Enum.map(fn den ->
        {:ok, file} = StringIO.open("YUV4MPEG2 W1 H1 A#{nom}:#{den}")
        {props, _stream} = Y4m.stream(file)
        assert [nom, den] == props.aspect_ratio
      end)
    end)

    {:ok, f} = StringIO.open("YUV4MPEG2 W1 H1 Ax:1")
    assert {:error, :invalid_aspect_ratio} == Y4m.stream(f)

    {:ok, f} = StringIO.open("YUV4MPEG2 W1 H1 A1:x")
    assert {:error, :invalid_aspect_ratio} == Y4m.stream(f)

    {:ok, f} = StringIO.open("YUV4MPEG2 W1 H1 A1?1")
    assert {:error, :invalid_aspect_ratio} == Y4m.stream(f)
  end

  test "read y4m header color space" do
    supported_color_spaces = [
      :C420,
      :C444
    ]

    for cs <- supported_color_spaces do
      {:ok, file} = StringIO.open("YUV4MPEG2 W1 H1 #{cs}")
      {props, _stream} = Y4m.stream(file)
      assert cs == props.color_space
    end

    unsupported_color_spaces = [
      :C420jpeg,
      :C420paldv,
      :C422,
      :Cmono
    ]

    for cs <- unsupported_color_spaces do
      {:ok, f} = StringIO.open("YUV4MPEG2 W1 H1 #{cs}")
      assert {:error, :unsupported_color_space} == Y4m.stream(f)
    end

    {:ok, f} = StringIO.open("YUV4MPEG2 W1 H1 C123")
    assert {:error, :invalid_color_space} == Y4m.stream(f)
  end

  test "iter y4m frames" do
    file_path = TestHelper.write_test_file(10)
    {_props, stream} = Y4m.stream(file_path)

    read_frames =
      stream
      |> Enum.map(fn [y, u, v] -> [y, u, v] |> Enum.map(&:binary.bin_to_list/1) end)
      |> Enum.take(11)

    assert 10 == length(read_frames)

    assert Enum.zip([0..9, read_frames])
           |> Enum.all?(fn {i, f} -> f == [[i, i], [i, i], [i, i]] end)
  end

  test "iter y4m iter frames nx" do
    file_path = TestHelper.write_test_file(10)
    {_props, stream} = Y4m.stream(file_path)

    read_frames =
      stream
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
    file_path = TestHelper.write_test_file(2)
    # take more frames than in file
    {props, stream} = Y4m.stream(file_path)
    assert %{color_space: :C444, frame_rate: [1, 1], height: 1, width: 2} == props

    [frame] = stream |> Enum.take(1)
    assert [<<0, 0>>, <<0, 0>>, <<0, 0>>] == frame
    [frame] = stream |> Enum.take(1)
    assert [<<1, 1>>, <<1, 1>>, <<1, 1>>] == frame

    # end of stream is reached, no more frames
    assert [] == stream |> Enum.take(1)
  end
end
