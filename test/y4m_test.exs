defmodule Y4mTest do
  use ExUnit.Case
  doctest Y4MDecoder

  test "read y4m header" do
    %Y4MDecoder{properties: props} = Y4MDecoder.open("test/sample_videos/test_video.y4m")

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

  yd

  test "read y4m frames" do
    %Y4MDecoder{properties: props} = dec = Y4MDecoder.open("test/sample_videos/example.y4m")

    assert props == %{
             aspect_ratio: [0, 0],
             frame_rate: [25, 1],
             height: 288,
             interlacing: :progressive,
             width: 384
           }

    frame = Y4MDecoder.next_frame(dec)
    # three planes y, u, v
    assert length(frame) == 3

    # all planes the same size
    [y_plane, u_plane, v_plane] = frame
    assert length(y_plane) == length(u_plane)
    assert length(u_plane) == length(v_plane)
  end
end
