# YUVMPEG2 Decoder
Tiny collection of convenience functions to read *.y4m files and iterate over the frames.

```elixir
{:ok, file} = File.open("my_file.y4m")

# read frames into Nx tensors
file |> Y4m.read()
|> Y4mReader.iter_frames()
|> Stream.map(fn [y,u,v] -> Nx.stack([
    Nx.from_binary(y, {:u, 8}),
    Nx.from_binary(u, {:u, 8}),
    Nx.from_binary(v, {:u, 8})])
end)
|> Enum.take(2)
```