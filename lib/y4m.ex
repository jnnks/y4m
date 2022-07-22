defmodule Y4m do
  @moduledoc """
  Module for working with y4m.
  """

  @doc """
  Reads y4m frames from a file on disk.

  ## Examples
      iex> {:ok, file} = File.open("my_file.y4m")
      iex> Y4m.decode(file)
      %Y4MDecoder{
        file: #PID<0.222.0>,
        properties: %{ ...  }
      }
  """
  @spec read(atom | pid) :: %Y4mReader{} | {:error, :invalid_header}
  def read(file), do: Y4mReader.read(file)

  @doc """
  Return inifnite lazy stream over all frames in this file stream.
  When the end of the file is reached, the file is reopenend again restarting the stream from the besinning of the file.

  ## Examples
      iex> Y4m.loop("my_file.y4m") |> Enum.take(4)
      [
        ...
      ]
  """
  @spec loop(binary) :: %Y4mFrameLoop{}
  def loop(file_path), do: Y4mFrameLoop.init(file_path)
end
