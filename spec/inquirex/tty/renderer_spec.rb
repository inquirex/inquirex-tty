# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inquirex::TTY::Renderer do
  let(:prompt) { instance_double(TTY::Prompt) }
  let(:renderer) { described_class.new(prompt:) }

  # Build a Node inline for testing individual render paths.
  def make_node(verb:, type: nil, question: "Question?", options: nil, hints: nil)
    Inquirex::Node.new(
      id:           :test,
      verb:,
      type:,
      question:,
      text:         question,
      options:,
      transitions:  [],
      skip_if:      nil,
      default:      nil,
      widget_hints: hints
    )
  end

  # Silence TTY output in display-verb tests.
  before { allow($stdout).to receive(:puts) }

  describe "#render" do
    context "with a :say display node" do
      let(:node) { make_node(verb: :say) }

      before { allow(prompt).to receive(:keypress) }

      it "returns nil" do
        expect(renderer.render(node)).to be_nil
      end
    end

    context "with a :btw display node" do
      let(:node) { make_node(verb: :btw) }

      before { allow(prompt).to receive(:keypress) }

      it "returns nil" do
        expect(renderer.render(node)).to be_nil
      end
    end

    context "with a :warning display node" do
      let(:node) { make_node(verb: :warning) }

      before { allow(prompt).to receive(:keypress) }

      it "returns nil" do
        expect(renderer.render(node)).to be_nil
      end
    end

    context "with a :header display node" do
      let(:node) { make_node(verb: :header, question: "Section Title") }

      before { allow(prompt).to receive(:keypress) }

      it "returns nil" do
        expect(renderer.render(node)).to be_nil
      end
    end

    context "with a :string ask node" do
      let(:node) { make_node(verb: :ask, type: :string) }

      before { allow(prompt).to receive(:ask).with("Question?").and_return("Alice") }

      it "returns the prompt answer" do
        expect(renderer.render(node)).to eq("Alice")
      end
    end

    context "with a :boolean confirm node" do
      let(:node) { make_node(verb: :confirm, type: :boolean) }

      before { allow(prompt).to receive(:yes?).with("Question?").and_return(true) }

      it "delegates to prompt.yes?" do
        expect(renderer.render(node)).to be(true)
      end
    end

    context "with an :integer ask node" do
      let(:node) { make_node(verb: :ask, type: :integer) }

      before { allow(prompt).to receive(:ask).with("Question?", convert: :int).and_return(42) }

      it "returns the integer value" do
        expect(renderer.render(node)).to eq(42)
      end
    end

    context "with a :decimal ask node" do
      let(:node) { make_node(verb: :ask, type: :decimal) }

      before { allow(prompt).to receive(:ask).with("Question?", convert: :float).and_return(3.14) }

      it "returns the float value" do
        expect(renderer.render(node)).to eq(3.14)
      end
    end

    context "with an :enum ask node" do
      let(:node) { make_node(verb: :ask, type: :enum, options: %w[A B C]) }

      before { allow(prompt).to receive(:select).with("Question?", %w[A B C]).and_return("A") }

      it "delegates to prompt.select" do
        expect(renderer.render(node)).to eq("A")
      end
    end

    context "with a :multi_enum ask node" do
      let(:node) { make_node(verb: :ask, type: :multi_enum, options: %w[X Y Z]) }

      before do
        allow(prompt).to receive(:multi_select)
          .with("Question?", %w[X Y Z], min: 1)
          .and_return(%w[X Z])
      end

      it "delegates to prompt.multi_select" do
        expect(renderer.render(node)).to eq(%w[X Z])
      end
    end

    context "with a :mask widget hint" do
      let(:hint) { Inquirex::WidgetHint.new(type: :mask, options: {}) }
      let(:node) { make_node(verb: :ask, type: :string, hints: { tty: hint }) }

      before { allow(prompt).to receive(:mask).with("Question?").and_return("secret") }

      it "delegates to prompt.mask" do
        expect(renderer.render(node)).to eq("secret")
      end
    end
  end
end
