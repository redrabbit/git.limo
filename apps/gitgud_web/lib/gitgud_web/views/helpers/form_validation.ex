defmodule GitGud.Web.FormValidation do
  @moduledoc """
  Conveniences for custom HTML input validations.

  This module *overloads* input functions defined by `Phoenix.HTML.Form` by passing custom
  `input_validations/2` to the HTML input target attributes.
  """

  @basic_inputs_with_arity Enum.filter(Phoenix.HTML.Form.__info__(:functions), fn {name, _arity} -> String.ends_with?(to_string(name), "_input") end)
  @extra_inputs_with_arity Enum.flat_map([:checkbox, :date_select, :datetime_select, :textarea, :time_select], &[{&1, 2}, {&1, 3}])
  @multi_inputs_with_arity Enum.flat_map([:radio_button, :select, :multiple_select], &[{&1, 3}, {&1, 4}])

  @doc "See `Phoenix.HTML.input_validations/2` for more details."
  def input_validations(form, field) do
    Phoenix.HTML.Form.input_validations(form, field)
  end

  for input_fn <- Enum.uniq(Enum.map(@basic_inputs_with_arity ++ @extra_inputs_with_arity, &elem(&1, 0))) do
    @doc "See `Phoenix.HTML.#{input_fn}/3` for more details."
    def unquote(input_fn)(form, field, opts \\ []) do
      apply(Phoenix.HTML.Form, unquote(input_fn), [form, field, Keyword.merge(opts, input_validations(form, field))])
    end
  end

  @doc "See `Phoenix.HTML.radio_button/4` for more details."
  def radio_button(form, field, value, opts \\ []) do
    Phoenix.HTML.Form.radio_button(form, field, value, Keyword.merge(opts, input_validations(form, field)))
  end

  @doc "See `Phoenix.HTML.select/4` for more details."
  def select(form, field, options, opts \\ []) do
    Phoenix.HTML.Form.select(form, field, options, Keyword.merge(opts, input_validations(form, field)))
  end

  @doc "See `Phoenix.HTML.multiple_select/4` for more details."
  def multiple_select(form, field, options, opts \\ []) do
    Phoenix.HTML.Form.multiple_select(form, field, options, Keyword.merge(opts, input_validations(form, field)))
  end

  defmacro __using__(_opts) do
    quote do
      import Phoenix.HTML.Form, except: unquote(@basic_inputs_with_arity ++ @extra_inputs_with_arity ++ @multi_inputs_with_arity)
      import GitGud.Web.FormValidation
    end
  end
end
