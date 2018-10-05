defmodule GitGud.Web.DateTimeFormatter do
  @moduledoc """
  Conveniences for formatting `DateTime`, `Date` and `Time` values.
  """

  @doc """
  Formats a date/time value using the given `format` string.
  """
  @spec datetime_format(DateTime.t(), binary) :: binary
  def datetime_format(datetime, format) do
    if String.contains?(format, "{relative}"),
      do: Timex.format!(datetime, "{relative}", :relative),
      else: Timex.format!(datetime, format)
  end
end
