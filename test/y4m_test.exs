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
    file_path = TestHelper.write_test_file(10)
    {:ok, file} = File.open(file_path)

    read_frames =
      Y4mReader.read(file)
      |> Y4mReader.iter_frames()
      |> Enum.map(fn [y, u, v] -> [y, u, v] |> Enum.map(&:binary.bin_to_list/1) end)
      |> Enum.take(11)

    assert 10 == length(read_frames)
    assert Enum.zip([1..10,read_frames]) |> Enum.all?(fn {i, f} -> f == [[i, i], [i, i], [i, i]] end)
  end

  test "iter y4m iter frames nx" do
    file_path = TestHelper.write_test_file(10)
    {:ok, file} = File.open(file_path)

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
    file_path = TestHelper.write_test_file(10)
    # take more frames than in file
    loop = Y4m.loop(file_path)
    frames = Enum.take(loop, 12)
    assert 12 == length(frames)

    # take first frame and first frame of restarted stream
    loop = Y4m.loop(file_path)
    assert [[<<1, 1>>, <<1, 1>>, <<1, 1>>]] == Enum.take(loop, 1)
    assert [<<1, 1>>, <<1, 1>>, <<1, 1>>] == Enum.take(loop, 10) |> Enum.at(9)
  end

  test "loop y4m file in genstage" do
    # This is a crash test.
    # For some reason the state of the frame loop enumerable is not carried over
    # in GenStage Producers. This will lead to a crash whenever the file is being
    # reopened.
    # This test is waiting for a crash for 100ms

    # build 10 frames of 2x1 pixels into test file

    file_path = TestHelper.write_test_file(10)

    {:ok, prod} = GenStage.start_link(TestFrameProducer, [file_path])
    {:ok, cons} = GenStage.start_link(TestFrameConsumer, [])

    GenStage.sync_subscribe(cons, to: prod, max_demand: 1)
    :timer.sleep(100)
    GenStage.stop(prod)
  end
end


defmodule TestFrameProducer do
  use GenStage

  def start_link(path), do: GenStage.start_link(__MODULE__, [path], name: __MODULE__)
  def init(file_path), do: {:producer, Y4m.loop(file_path)}
  def handle_demand(_demand, loop) do
    {loop, item} = Y4mFrameLoop.next(loop)
    {:noreply, [item], loop}
  end
end

defmodule TestFrameConsumer do
  use GenStage

  def start_link(_), do: GenStage.start_link(__MODULE__, [], name: __MODULE__)
  def init(_), do: {:consumer, 0}
  def handle_events(_events, _from, _) do
    {:noreply, [], 0}
  end
end
