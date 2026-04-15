# frozen_string_literal: true

# Small fixture with an LLM clarify verb, used by run_spec to exercise
# the llm-step branch in the Run command without hitting a real API.
Inquirex.define id: "llm-smoke", version: "1.0.0" do
  meta title: "LLM Smoke Test"

  start :describe

  ask :describe do
    type :text
    question "Describe yourself."
    transition to: :extracted
  end

  clarify :extracted do
    from :describe
    prompt "Extract structured info from the description."
    schema name: :string, role: :string
    transition to: :done
  end

  say :done do
    text "Thanks!"
  end
end
