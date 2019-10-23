defmodule GitGud.Web.DateTimeFormatter do
  @moduledoc """
  Conveniences for formatting `DateTime`, `Date` and `Time` values.
  """

  import Phoenix.HTML.Tag

  @doc """
  Renders a date/time widget using the given `format` string.
  """
  @spec datetime_format(DateTime.t, binary) :: binary
  def datetime_format(%DateTime{} = datetime, format) do
    datetime_str = DateTime.to_iso8601(datetime)
    if String.contains?(format, "{relative}"),
      do: content_tag(:time, Timex.format!(datetime, "{relative}", :relative), datetime: datetime_str, data_tooltip: datetime_str, class: "tooltip"),
    else: content_tag(:time, Timex.format!(datetime, format), datetime: datetime_str)
  end

  def datetime_format(%NaiveDateTime{} = datetime, format) do
    datetime_str = NaiveDateTime.to_iso8601(datetime)
    if String.contains?(format, "{relative}"),
      do: content_tag(:time, Timex.format!(datetime, "{relative}", :relative), datetime: datetime_str, data_tooltip: datetime_str, class: "tooltip"),
    else: content_tag(:time, Timex.format!(datetime, format), datetime: datetime_str)
  end

  def datetime_format(%Date{} = date, format) do
    date_str = Date.to_iso8601(date)
    if String.contains?(format, "{relative}"),
      do: content_tag(:time, Timex.format!(date, "{relative}", :relative), date: date_str, data_tooltip: date_str, class: "tooltip"),
    else: content_tag(:time, Timex.format!(date, format), date: date_str)
  end

  @doc """
  Formats a date/time value using the given `format` string.
  """
  @spec datetime_format_str(Datetime.t, binary) :: binary
  def datetime_format_str(datetime, format) do
    if String.contains?(format, "{relative}"),
      do: Timex.format!(datetime, "{relative}", :relative),
    else: Timex.format!(datetime, format)
  end
end
