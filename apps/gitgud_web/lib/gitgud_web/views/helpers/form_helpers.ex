defmodule GitGud.Web.FormHelpers do
  @moduledoc """
  Conveniences for custom HTML input validations.

  This module *overloads* input functions defined by `Phoenix.HTML.Form` by passing custom
  `input_validations/2` to the HTML input target attributes.
  """

  import Phoenix.HTML.Form, only: [input_id: 2, input_name: 2, input_value: 2]

  import GitGud.GraphQL.Schema, only: [to_relay_id: 1]
  import GitGud.Web.ReactComponents, only: [react_component: 4]

  @basic_inputs_with_arity Enum.filter(Phoenix.HTML.Form.__info__(:functions), fn
    {:color_input, _arity} -> false
    {name, _arity} -> String.ends_with?(to_string(name), "_input")
  end)
  @extra_inputs_with_arity Enum.flat_map([:checkbox, :date_select, :datetime_select, :textarea, :time_select], &[{&1, 2}, {&1, 3}])
  @multi_inputs_with_arity Enum.flat_map([:radio_button, :select, :multiple_select], &[{&1, 3}, {&1, 4}])

  @doc """
  Generates an user input.
  """
  def user_input(form, field, opts \\ []) do
    {reject, opts} = Keyword.pop(opts, :reject, [])
    react_component("user-input", [id: input_id(form, field), name: input_name(form, field), reject: Enum.map(reject, &to_relay_id/1)], opts, do: [
      text_input(form, field, class: "input")
    ])
  end

  @doc """
  See `Phoenix.HTML.input_validations/2` for more details.
  """
  def input_validations(form, field) do
    Phoenix.HTML.Form.input_validations(form, field)
  end

  for input_fn <- Enum.uniq(Enum.map(@basic_inputs_with_arity ++ @extra_inputs_with_arity, &elem(&1, 0))) do
    @doc """
    See `Phoenix.HTML.#{input_fn}/3` for more details.
    """
    def unquote(input_fn)(form, field, opts \\ []) do
      apply(Phoenix.HTML.Form, unquote(input_fn), [form, field, input_options(form, field, opts)])
    end
  end

  @doc """
  See `Phoenix.HTML.radio_button/4` for more details.
  """
  def radio_button(form, field, value, opts \\ []) do
    Phoenix.HTML.Form.radio_button(form, field, value, input_options(form, field, opts))
  end

  @doc """
  See `Phoenix.HTML.select/4` for more details.
  """
  def select(form, field, options, opts \\ []) do
    Phoenix.HTML.Form.select(form, field, options, input_options(form, field, opts))
  end

  @doc """
  See `Phoenix.HTML.multiple_select/4` for more details.
  """
  def multiple_select(form, field, options, opts \\ []) do
    Phoenix.HTML.Form.multiple_select(form, field, options, input_options(form, field, opts))
  end

  defmacro __using__(_opts) do
    quote do
      import Phoenix.HTML.Form, except: unquote(@basic_inputs_with_arity ++ @extra_inputs_with_arity ++ @multi_inputs_with_arity)
      import GitGud.Web.FormHelpers
    end
  end

  #
  # Helpers
  #

  defp input_options(form, field, opts) do
    Keyword.merge(input_validations(form, field), opts)
  end
end
