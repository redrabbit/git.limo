defmodule GitGud.Telemetry.GitInstrumentHandler do
  @moduledoc false

  require Logger

  def handle_event([:gitrekt, :git_agent, :call], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    agent_node = :erlang.node(meta.pid)
    if agent_node != Node.self() do
      if parent_span = Appsignal.Tracer.current_span() do
        time = :os.system_time(:nanosecond)
        span = Appsignal.Tracer.create_span("http_request", parent_span, start_time: time - :erlang.convert_time_unit(duration, :microsecond, :nanosecond), pid: self())
        if op != :transaction do
          span
          |> Appsignal.Span.set_name("GitRekt.GitAgent.#{map_git_agent_op_sig(op, args)}")
          |> Appsignal.Span.set_attribute("appsignal:category", "#{op}.git")
        else
          span
          |> Appsignal.Span.set_name("GitRekt.GitAgent.transaction/2")
          |> Appsignal.Span.set_attribute("appsignal:category", "#{op}.git")
          |> Appsignal.Span.set_attribute("appsignal:body", map_git_agent_op_sig(op, args))
        end
        Appsignal.Tracer.close_span(span, end_time: time)
      end
    end
  end

  def handle_event([:gitrekt, :git_agent, :call_stream], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    agent_node = :erlang.node(meta.pid)
    if agent_node != Node.self() do
      if parent_span = Appsignal.Tracer.current_span() do
        time = :os.system_time(:nanosecond)
        "http_request"
        |> Appsignal.Tracer.create_span(parent_span, start_time: time - :erlang.convert_time_unit(duration, :microsecond, :nanosecond), pid: self())
        |> Appsignal.Span.set_name("GitRekt.GitAgent.#{map_git_agent_op_sig(op, args)}")
        |> Appsignal.Span.set_attribute("appsignal:category", "stream.git")
        |> Appsignal.Tracer.close_span(end_time: time)
      end
    end
  end

  def handle_event([:gitrekt, :git_agent, :execute], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    if op != :transaction do
      if parent_span = Appsignal.Tracer.current_span(meta.pid) do
        time = :os.system_time(:nanosecond)
        "http_request"
        |> Appsignal.Tracer.create_span(parent_span, start_time: time - :erlang.convert_time_unit(duration, :microsecond, :nanosecond), pid: self())
        |> Appsignal.Span.set_name("GitRekt.GitAgent.#{map_git_agent_op_sig(op, args)}")
        |> Appsignal.Span.set_attribute("appsignal:category", "#{op}.git")
        |> Appsignal.Tracer.close_span(end_time: time)
      end
    end
  end

  def handle_event([:gitrekt, :git_agent, :transaction_start], _measurements, %{op: op, args: args} = meta, _config) do
    if parent_span = Appsignal.Tracer.current_span(meta.pid) do
      "http_request"
      |> Appsignal.Tracer.create_span(parent_span)
      |> Appsignal.Span.set_name("GitRekt.GitAgent.#{map_git_agent_transaction(op, args)}")
      |> Appsignal.Span.set_attribute("appsignal:category", "transaction.git")
      |> Appsignal.Span.set_attribute("appsignal:body", map_git_agent_op_sig(op, args))
    end
  end

  def handle_event([:gitrekt, :git_agent, :transaction_stop], _measurements, _meta, _config) do
    Appsignal.Tracer.close_span(Appsignal.Tracer.current_span())
  end

  def handle_event([:gitrekt, :git_agent, :stream], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    if parent_span = Appsignal.Tracer.current_span(meta.pid) do
      time = :os.system_time(:nanosecond)
      "http_request"
      |> Appsignal.Tracer.create_span(parent_span, start_time: time - :erlang.convert_time_unit(duration, :microsecond, :nanosecond), pid: self())
      |> Appsignal.Span.set_name("GitRekt.GitAgent.#{map_git_agent_op_sig(op, args)}")
      |> Appsignal.Span.set_attribute("appsignal:category", "stream.git")
      |> Appsignal.Tracer.close_span(end_time: time)
    end
  end

  def handle_event([:gitrekt, :wire_protocol, :start], _measurements, %{service: service, state: state} = _meta, _config) do
    if parent_span = Appsignal.Tracer.current_span() do
      "http_request"
      |> Appsignal.Tracer.create_span(parent_span)
      |> Appsignal.Span.set_name("GitRekt.WireProtocol.#{Macro.camelize(to_string(service))}")
      |> Appsignal.Span.set_attribute("appsignal:category", "#{state}.wire_protocol")
    end
  end

  def handle_event([:gitrekt, :wire_protocol, :stop], _measurements, _meta, _config) do
    Appsignal.Tracer.close_span(Appsignal.Tracer.current_span())
  end

  #
  # Helpers
  #

  defp map_git_agent_op_sig(:transaction, [_name, fun]), do: inspect(fun)
  defp map_git_agent_op_sig(op, args), do: "#{op}/#{length(args) + 1}"

  defp map_git_agent_transaction(:transaction, [nil, _fun]), do: "transaction/2"
  defp map_git_agent_transaction(:transaction, [name, _fun]) do
    [op|args] = Tuple.to_list(name)
    map_git_agent_op_sig(op, args)
  end
end
