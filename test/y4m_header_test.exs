defmodule Y4mHeaderTest do
  use ExUnit.Case

  @tag :header
  test "read y4m header" do
    {:ok, file} =
      StringIO.open("YUV4MPEG2 W512 H288 F2:1 Ip A1:1 C444 XCOLORRANGE=LIMITED XYSCSS=444")

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

  @tag :header
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

  @tag :header
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

  @tag :header
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

  @tag :header
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

  @tag :header
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

  @tag :header
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
end
