defmodule GitRekt.GitStream do
  @moduledoc """
  Functions for creating and transforming Git streamable resources.
  """

  defstruct [:enum, :__ref__]

  @type t :: %__MODULE__{enum: Enumerable.t, __ref__: reference}

  @doc """
  Creates a new stream.
  """
  @spec new(reference, term, (Stream.acc -> {[Stream.element], Stream.acc} | {:halt, Stream.acc})) :: t
  def new(resource \\ nil, acc, next_fun) do
    %__MODULE__{enum: Stream.resource(fn -> acc end, next_fun, &after_fun/1), __ref__: resource || acc}
  end

  @doc """
  Transforms the given `stream`.
  """
  @spec transform(Enumerable.t, (Stream.acc -> {[Stream.element], Stream.acc} | {:halt, Stream.acc})) :: t
  def transform(%Stream{enum: %__MODULE__{enum: enum, __ref__: ref}} = stream, next_fun) do
    %__MODULE__{enum: struct(stream, enum: Stream.resource(fn -> enum end, next_fun, &after_fun/1)), __ref__: ref}
  end

  #
  # Protocols
  #

  defimpl Enumerable do
    def reduce(stream, acc, fun), do: Enumerable.reduce(stream.enum, acc, fun)

    def count(_lazy), do: {:error, __MODULE__}

    def member?(_lazy, _value), do: {:error, __MODULE__}

    def slice(_lazy), do: {:error, __MODULE__}
  end

  defimpl Inspect do
    def inspect(stream, _opts), do: "<GitStream:#{inspect stream.__ref__}>"
  end

  #
  # Helpers
  #

  defp after_fun(_acc), do: :ok
end
