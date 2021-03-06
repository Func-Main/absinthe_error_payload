defmodule AbsintheErrorPayload.PayloadTest do
  @moduledoc """
  Test conversion of changeset errors to ValidationMessage structs

  """
  use ExUnit.Case

  import Ecto.Changeset
  import AbsintheErrorPayload.Payload

  alias Absinthe.Resolution
  alias AbsintheErrorPayload.Payload
  alias AbsintheErrorPayload.ValidationMessage

  def resolution(value) do
    %Resolution{
      value: value,
      adapter: "",
      context: "",
      root_value: "",
      schema: "",
      source: ""
    }
  end

  defp resolution_error(error) do
    %Resolution{
      errors: error,
      adapter: "",
      context: "",
      root_value: "",
      schema: "",
      source: ""
    }
  end

  def payload(successful, messages \\ [], result \\ nil) do
    %Payload{
      successful: successful,
      messages: messages,
      result: result
    }
  end

  def assert_error_payload(messages, result) do
    assert %{value: value, errors: _} = result

    expected = payload(false, messages)

    assert expected.successful == value.successful
    assert expected.result == value.result

    for message <- messages do
      message = convert_field_name(message)

      assert Enum.find_value(value.messages, &(message == &1)),
             "Expected to find \n#{inspect(message)}\n in \n#{inspect(value.messages)}"
    end
  end

  def assert_resolution_error_payload(errors, resolution) do
    assert errors == resolution.errors
  end

  describe "build_payload/2" do
    test "validation message tuple" do
      message = %ValidationMessage{code: :required}
      resolution = resolution(message)
      result = build_payload(resolution, nil)

      assert_error_payload([message], result)
    end

    test "error, validation message tuple" do
      message = %ValidationMessage{code: :required}
      resolution = resolution({:error, message})
      result = build_payload(resolution, nil)

      assert_error_payload([message], result)
    end

    test "error, string message tuple" do
      resolution = resolution({:error, "an error"})
      result = build_payload(resolution, nil)

      message = %ValidationMessage{code: :unknown, message: "an error", template: "an error"}
      assert_error_payload([message], result)
    end

    test "error list" do
      messages = [%ValidationMessage{code: :required}, %ValidationMessage{code: :max}]
      resolution = resolution({:error, messages})

      result = build_payload(resolution, nil)

      assert %{value: value} = result

      expected = payload(false, messages)
      assert expected == value
    end

    test "error tuple with an atom message" do
      resolution = resolution({:error, :an_error})

      result = build_payload(resolution, nil)

      assert %{value: value} = result

      expected = payload(false, [%ValidationMessage{code: :unknown, field: nil, key: nil, message: "an_error", options: [], template: "an_error"}])
      assert expected == value
    end

    test "error changeset" do
      changeset =
        {%{}, %{title: :string, title_lang: :string}}
        |> Ecto.Changeset.cast(%{}, [:title, :title_lang])
        |> add_error(:title, "error 1")
        |> add_error(:title, "error 2")
        |> add_error(:title_lang, "error 3")

      resolution = resolution(changeset)

      result = build_payload(resolution, nil)

      messages = [
        %ValidationMessage{code: :unknown, message: "error 1", template: "error 1", field: :title, key: :title},
        %ValidationMessage{code: :unknown, message: "error 2", template: "error 2", field: :title, key: :title},
        %ValidationMessage{code: :unknown, message: "error 3", template: "error 3", field: :titleLang, key: :titleLang}
      ]

      assert_error_payload(messages, result)
    end

    test "valid changeset" do
      changeset =
        {%{}, %{title: :string, body: :string}}
        |> Ecto.Changeset.cast(%{}, [:title, :body])

      resolution = resolution(changeset)

      result = build_payload(resolution, nil)
      assert %{value: value} = result

      assert value.successful == true
      assert value.messages == []
      assert value.result == changeset
    end

    test "map" do
      map = %{something: "something"}
      resolution = resolution(map)

      result = build_payload(resolution, nil)
      assert %{value: value} = result

      assert value.successful == true
      assert value.messages == []
      assert value.result == map
    end

    test "error from resolution, validation message" do
      message = %ValidationMessage{code: :required}
      resolution = resolution_error([message])
      result = build_payload(resolution, nil)

      assert_error_payload([message], result)
      assert_resolution_error_payload([message], result)
    end

    test "error from resolution, string message" do
      errors = ["an error"]
      resolution = resolution_error(errors)
      result = build_payload(resolution, nil)

      message = %ValidationMessage{code: :unknown, message: "an error", template: "an error"}
      assert_error_payload([message], result)
      assert_resolution_error_payload(errors, result)
    end

    test "error from resolution, atom message" do
      errors = [:an_error]
      resolution = resolution_error(errors)
      result = build_payload(resolution, nil)

      message = %ValidationMessage{code: :unknown, message: "an_error", template: "an_error"}
      assert_error_payload([message], result)
      assert_resolution_error_payload(errors, result)
    end

    test "error from resolution, string message list" do
      errors = ["an error", "another error"]
      resolution = resolution_error(errors)
      result = build_payload(resolution, nil)

      messages = [
        %ValidationMessage{code: :unknown, message: "an error", template: "an error"},
        %ValidationMessage{code: :unknown, message: "another error", template: "another error"}
      ]

      assert_error_payload(messages, result)
      assert_resolution_error_payload(errors, resolution)
    end

    test "error from resolution, error list" do
      messages = [%ValidationMessage{code: :required}, %ValidationMessage{code: :max}]
      resolution = resolution_error(messages)

      result = build_payload(resolution, nil)

      assert %{value: _value} = result

      assert_error_payload(messages, result)
    end
  end
end
