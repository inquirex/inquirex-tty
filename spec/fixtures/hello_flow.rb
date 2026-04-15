# frozen_string_literal: true

# Minimal fixture used by flow_loader_spec and renderer_spec.
Inquirex.define id: "hello-world", version: "1.0.0" do
  meta title: "Hello World"

  start :name

  ask :name do
    type :string
    question "What is your name?"
    widget target: :tty, type: :text_input
    transition to: :farewell
  end

  say :farewell do
    text "Thanks for stopping by!"
  end
end
