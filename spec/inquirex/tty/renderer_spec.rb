# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/AnyInstance, RSpec/NestedGroups, RSpec/ContextWording
RSpec.describe Inquirex::TTY::Renderer do
  let(:prompt) { instance_double(TTY::Prompt) }
  let(:renderer) { described_class.new(prompt:) }

  # Build a Node inline for testing individual render paths.
  def make_node(verb:, type: nil, question: "Question?", text: nil, options: nil, hints: nil)
    Inquirex::Node.new(
      id:           :test,
      verb:,
      type:,
      question:,
      text:         text || question,
      options:,
      transitions:  [],
      skip_if:      nil,
      default:      nil,
      widget_hints: hints
    )
  end

  # Silence TTY output in display-verb tests.
  before do
    allow($stdout).to receive(:puts)
    allow(prompt).to receive(:keypress)
  end

  describe "#render" do
    context "with a :say display node" do
      let(:node) { make_node(verb: :say) }

      it "returns nil" do
        expect(renderer.render(node)).to be_nil
      end
    end

    context "with a :btw display node" do
      let(:node) { make_node(verb: :btw) }

      it "returns nil" do
        expect(renderer.render(node)).to be_nil
      end
    end

    context "with a :warning display node" do
      let(:node) { make_node(verb: :warning) }

      it "returns nil" do
        expect(renderer.render(node)).to be_nil
      end
    end

    context "with a :header display node" do
      let(:node) { make_node(verb: :header, text: "Section Title") }

      it "returns nil" do
        expect(renderer.render(node)).to be_nil
      end

      context "when TTY::Font rendering raises" do
        before do
          allow_any_instance_of(TTY::Font).to receive(:write).and_raise(StandardError, "bad char")
        end

        it "falls back to a bordered box and still returns nil" do
          expect(renderer.render(node)).to be_nil
        end
      end
    end

    context "with an unknown display verb (fallback branch)" do
      # A duck-typed stand-in — Node is frozen, so we can't stub methods on it.
      let(:node) do
        Struct.new(:verb, :text) do
          def display? = true
        end.new(:mystery_display, "fallback text")
      end

      it "prints node.text and returns nil" do
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

    context "with a :currency ask node" do
      let(:node) { make_node(verb: :ask, type: :currency) }

      before { allow(prompt).to receive(:ask).with("Question?", convert: :float).and_return(99.99) }

      it "delegates to currency_input (prompt.ask with float convert)" do
        expect(renderer.render(node)).to eq(99.99)
      end
    end

    context "with an :enum ask node (plain array)" do
      let(:node) { make_node(verb: :ask, type: :enum, options: %w[A B C]) }

      before { allow(prompt).to receive(:select).with("Question?", %w[A B C]).and_return("A") }

      it "delegates to prompt.select with the values" do
        expect(renderer.render(node)).to eq("A")
      end
    end

    context "with an :enum ask node (hash options — labels)" do
      let(:node) do
        make_node(
          verb:    :ask,
          type:    :enum,
          options: { "single" => "Single", "married" => "Married, Filing Jointly" }
        )
      end

      before do
        allow(prompt).to receive(:select)
          .with("Question?", { "Single" => "single", "Married, Filing Jointly" => "married" })
          .and_return("married")
      end

      it "passes a {label => value} hash to TTY::Prompt" do
        expect(renderer.render(node)).to eq("married")
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

    context "with an :enum_select widget hint" do
      let(:hint) { Inquirex::WidgetHint.new(type: :enum_select, options: {}) }
      let(:node) do
        make_node(verb: :ask, type: :enum, options: %w[A B], hints: { tty: hint })
      end

      before do
        allow(prompt).to receive(:enum_select).with("Question?", %w[A B]).and_return("A")
      end

      it "delegates to prompt.enum_select" do
        expect(renderer.render(node)).to eq("A")
      end
    end

    context "with a :slider widget hint and bounds" do
      let(:hint) do
        Inquirex::WidgetHint.new(type: :slider, options: { min: 0, max: 10, step: 2 })
      end
      let(:node) { make_node(verb: :ask, type: :integer, hints: { tty: hint }) }

      before do
        allow(prompt).to receive(:slider).with("Question?", min: 0, max: 10, step: 2).and_return(6)
      end

      it "passes min/max/step to prompt.slider" do
        expect(renderer.render(node)).to eq(6)
      end
    end

    context "with a :slider widget hint and no bounds" do
      let(:hint) { Inquirex::WidgetHint.new(type: :slider, options: {}) }
      let(:node) { make_node(verb: :ask, type: :integer, hints: { tty: hint }) }

      before { allow(prompt).to receive(:slider).with("Question?").and_return(3) }

      it "calls prompt.slider with no extra kwargs" do
        expect(renderer.render(node)).to eq(3)
      end
    end

    context "with a :multiline widget hint" do
      let(:hint) { Inquirex::WidgetHint.new(type: :multiline, options: {}) }
      let(:node) { make_node(verb: :ask, type: :text, hints: { tty: hint }) }

      before do
        answers = ["line one", "line two", ""]
        allow(prompt).to receive(:ask) { |*_a, &_b| answers.shift }
      end

      it "collects lines until a blank submit" do
        expect(renderer.render(node)).to eq("line one\nline two")
      end
    end

    context "with a :multiline widget hint and immediate blank line" do
      let(:hint) { Inquirex::WidgetHint.new(type: :multiline, options: {}) }
      let(:node) { make_node(verb: :ask, type: :text, hints: { tty: hint }) }

      before { allow(prompt).to receive(:ask).and_return(nil) }

      it "returns nil when no content was entered" do
        expect(renderer.render(node)).to be_nil
      end
    end

    context "with an unknown widget hint type (fallback to text_input)" do
      let(:hint) { Inquirex::WidgetHint.new(type: :unknown_widget, options: {}) }
      let(:node) { make_node(verb: :ask, type: :string, hints: { tty: hint }) }

      before { allow(prompt).to receive(:ask).with("Question?").and_return("fallback") }

      it "falls back to render_text_input" do
        expect(renderer.render(node)).to eq("fallback")
      end
    end

    context "aliased widget types (date, email, phone, textarea)" do
      %i[date_picker email_input phone_input].each do |widget_type|
        it "renders #{widget_type} via text_input" do
          hint = Inquirex::WidgetHint.new(type: widget_type, options: {})
          node = make_node(verb: :ask, type: :string, hints: { tty: hint })
          allow(prompt).to receive(:ask).with("Question?").and_return("ok")
          expect(renderer.render(node)).to eq("ok")
        end
      end

      it "renders :textarea via multiline collector" do
        hint = Inquirex::WidgetHint.new(type: :textarea, options: {})
        node = make_node(verb: :ask, type: :text, hints: { tty: hint })
        allow(prompt).to receive(:ask).and_return("only line", "")
        expect(renderer.render(node)).to eq("only line")
      end
    end
  end

  describe "#thinking" do
    it "prints a magenta separator and a bolded message" do
      expect { renderer.thinking("Asking Claude...") }.not_to raise_error
    end
  end

  describe "#show_extraction" do
    it "prints an extracted header, values, and a separator" do
      expect { renderer.show_extraction(name: "Alice", industry: nil, notes: "") }.not_to raise_error
    end

    it "handles a Hash with all-populated values" do
      expect { renderer.show_extraction(industry: "tech", employees: 42) }.not_to raise_error
    end
  end

  describe "#effective_tty_hint (private fallback)" do
    it "falls back to the registry when the node lacks #effective_widget_hint_for" do
      plain = Object.new
      def plain.type = :string
      def plain.display? = false
      allow(plain).to receive(:respond_to?).and_call_original
      allow(plain).to receive(:respond_to?).with(:effective_widget_hint_for).and_return(false)
      allow(Inquirex::WidgetRegistry).to receive(:default_hint_for).and_return(nil)
      hint = renderer.send(:effective_tty_hint, plain)
      expect(hint.type).to eq(:text_input)
    end
  end
end
# rubocop:enable RSpec/AnyInstance, RSpec/NestedGroups, RSpec/ContextWording
