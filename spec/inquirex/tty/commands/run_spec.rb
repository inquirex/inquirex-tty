# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# `allow_any_instance_of` is the cleanest lever for objects the CLI creates
# internally (Engine, LLM adapters, TTY::Font) — we would otherwise have to
# redesign the command for DI just for tests.
# rubocop:disable RSpec/AnyInstance, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
RSpec.describe Inquirex::TTY::Commands::Run do
  subject(:command) { described_class.new }

  let(:hello_flow_path) { File.expand_path("../../../fixtures/hello_flow.rb", __dir__) }
  let(:llm_flow_path)   { File.expand_path("../../../fixtures/llm_flow.rb", __dir__) }

  describe "#call" do
    context "when the file does not exist" do
      it "exits with status 1" do
        expect { command.call(flow_file: "/no/such/file.rb") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end

    context "with a valid flow and a stubbed renderer" do
      let(:definition) { Inquirex::TTY::FlowLoader.load(hello_flow_path) }
      let(:prompt)     { instance_double(TTY::Prompt) }
      let(:renderer)   { Inquirex::TTY::Renderer.new(prompt:) }

      before do
        allow(Inquirex::TTY::FlowLoader).to receive(:load).and_return(definition)
        allow(Inquirex::TTY::Renderer).to receive(:new).and_return(renderer)
        allow(renderer).to receive(:render) do |node|
          node.display? ? nil : "test answer"
        end
        allow($stdout).to receive(:puts)
        allow($stderr).to receive(:puts)
      end

      it "completes without raising" do
        expect { command.call(flow_file: hello_flow_path) }.not_to raise_error
      end

      context "with an --output file" do
        let(:tmpfile) { Tempfile.new(["run", ".json"]) }

        after { tmpfile.close; tmpfile.unlink }

        it "writes JSON results to the file" do
          command.call(flow_file: hello_flow_path, output: tmpfile.path)
          payload = JSON.parse(File.read(tmpfile.path))
          expect(payload).to include("flow_file", "path_taken", "answers", "steps_completed")
        end
      end
    end

    context "when the engine raises an Inquirex error" do
      let(:definition) { Inquirex::TTY::FlowLoader.load(hello_flow_path) }

      before do
        allow(Inquirex::TTY::FlowLoader).to receive(:load).and_return(definition)
        allow_any_instance_of(Inquirex::Engine)
          .to receive(:finished?).and_raise(Inquirex::Errors::Error, "kaboom")
      end

      it "exits with status 1" do
        expect { command.call(flow_file: hello_flow_path) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end

    context "with an LLM flow (clarify verb)" do
      let(:definition) { Inquirex::TTY::FlowLoader.load(llm_flow_path) }
      let(:prompt)     { instance_double(TTY::Prompt) }
      let(:renderer)   { Inquirex::TTY::Renderer.new(prompt:) }

      before do
        allow(Inquirex::TTY::FlowLoader).to receive(:load).and_return(definition)
        allow(Inquirex::TTY::Renderer).to receive(:new).and_return(renderer)
        allow(renderer).to receive(:render) do |node|
          node.display? ? nil : "I'm Alice, a sysadmin."
        end
        allow(renderer).to receive(:thinking)
        allow(renderer).to receive(:show_extraction)
        # Force NullAdapter regardless of the user's shell env
        stub_const("ENV", ENV.to_h.merge("INQUIREX_LLM_ADAPTER" => "null"))
        # NullAdapter returns Hash so the clarify branch fires
        allow_any_instance_of(Inquirex::LLM::NullAdapter)
          .to receive(:call).and_return({ name: "Alice", role: "sysadmin" })
        allow($stdout).to receive(:puts)
        allow($stderr).to receive(:puts)
      end

      it "runs through the LLM step and prints the extraction" do
        expect { command.call(flow_file: llm_flow_path) }.not_to raise_error
        expect(renderer).to have_received(:show_extraction).with(name: "Alice", role: "sysadmin")
      end
    end

    context "when the LLM step raises an error" do
      let(:definition) { Inquirex::TTY::FlowLoader.load(llm_flow_path) }
      let(:prompt)     { instance_double(TTY::Prompt) }
      let(:renderer)   { Inquirex::TTY::Renderer.new(prompt:) }

      before do
        allow(Inquirex::TTY::FlowLoader).to receive(:load).and_return(definition)
        allow(Inquirex::TTY::Renderer).to receive(:new).and_return(renderer)
        allow(renderer).to receive(:render) do |node|
          node.display? ? nil : "some text"
        end
        allow(renderer).to receive(:thinking)
        stub_const("ENV", ENV.to_h.merge("INQUIREX_LLM_ADAPTER" => "null"))
        allow_any_instance_of(Inquirex::LLM::NullAdapter)
          .to receive(:call).and_raise(StandardError, "llm down")
        allow($stdout).to receive(:puts)
        allow($stderr).to receive(:puts)
      end

      it "propagates the error (caught as an engine error → exit 1)" do
        expect { command.call(flow_file: llm_flow_path) }
          .to raise_error(StandardError, /llm down/)
      end
    end
  end

  describe "#build_llm_adapter (private)" do
    before do
      # Clear every adapter-selecting env var for a clean slate
      stub_const("ENV",
        ENV.to_h.merge(
          "INQUIREX_LLM_ADAPTER" => "",
          "ANTHROPIC_API_KEY"    => "",
          "OPENAI_API_KEY"       => ""
        ))
    end

    it "defaults to NullAdapter when no keys are set" do
      expect(command.send(:build_llm_adapter)).to be_a(Inquirex::LLM::NullAdapter)
    end

    it "honors INQUIREX_LLM_ADAPTER=null" do
      stub_const("ENV", ENV.to_h.merge("INQUIREX_LLM_ADAPTER" => "null"))
      expect(command.send(:build_llm_adapter)).to be_a(Inquirex::LLM::NullAdapter)
    end

    it "honors INQUIREX_LLM_ADAPTER=anthropic" do
      stub_const("ENV",
        ENV.to_h.merge(
          "INQUIREX_LLM_ADAPTER" => "anthropic",
          "ANTHROPIC_API_KEY"    => "sk-test"
        ))
      expect(command.send(:build_llm_adapter)).to be_a(Inquirex::LLM::AnthropicAdapter)
    end

    it "honors INQUIREX_LLM_ADAPTER=openai" do
      stub_const("ENV",
        ENV.to_h.merge(
          "INQUIREX_LLM_ADAPTER" => "openai",
          "OPENAI_API_KEY"       => "sk-test"
        ))
      expect(command.send(:build_llm_adapter)).to be_a(Inquirex::LLM::OpenAIAdapter)
    end

    it "picks Anthropic when ANTHROPIC_API_KEY is set" do
      stub_const("ENV", ENV.to_h.merge("ANTHROPIC_API_KEY" => "sk-test"))
      expect(command.send(:build_llm_adapter)).to be_a(Inquirex::LLM::AnthropicAdapter)
    end

    it "picks OpenAI when only OPENAI_API_KEY is set" do
      stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "sk-test"))
      expect(command.send(:build_llm_adapter)).to be_a(Inquirex::LLM::OpenAIAdapter)
    end
  end

  describe "#adapter_label (private)" do
    it "returns 'Claude' for the Anthropic adapter" do
      adapter = Inquirex::LLM::AnthropicAdapter.allocate
      expect(command.send(:adapter_label, adapter)).to eq("Claude")
    end

    it "returns 'GPT' for the OpenAI adapter" do
      adapter = Inquirex::LLM::OpenAIAdapter.allocate
      expect(command.send(:adapter_label, adapter)).to eq("GPT")
    end

    it "returns 'the null adapter' for anything else" do
      expect(command.send(:adapter_label, Object.new)).to eq("the null adapter")
    end
  end

  describe "#show_banner (private)" do
    let(:definition) { Inquirex::TTY::FlowLoader.load(hello_flow_path) }

    before { allow($stdout).to receive(:puts) }

    it "prints the title without raising" do
      expect { command.send(:show_banner, definition) }.not_to raise_error
    end

    it "falls back to a tty-box when TTY::Font fails" do
      allow_any_instance_of(TTY::Font).to receive(:write).and_raise(StandardError, "no font")
      expect { command.send(:show_banner, definition) }.not_to raise_error
    end
  end

  describe "#load_dotenv! (private)" do
    it "reads key=value pairs from a .env file near the flow" do
      Dir.mktmpdir("dotenv") do |dir|
        File.write(File.join(dir, ".env"), "INQUIREX_TEST_VAR=hello\n")
        File.write(File.join(dir, "flow.rb"), "# not a real flow")
        stub_const("ARGV", [File.join(dir, "flow.rb")])
        ENV.delete("INQUIREX_TEST_VAR")
        command.send(:load_dotenv!)
        expect(ENV.fetch("INQUIREX_TEST_VAR", nil)).to eq("hello")
      ensure
        ENV.delete("INQUIREX_TEST_VAR")
      end
    end

    it "does not overwrite variables already set in the environment" do
      Dir.mktmpdir("dotenv") do |dir|
        File.write(File.join(dir, ".env"), "INQUIREX_TEST_VAR=from_file\n")
        File.write(File.join(dir, "flow.rb"), "# not a real flow")
        stub_const("ARGV", [File.join(dir, "flow.rb")])
        ENV["INQUIREX_TEST_VAR"] = "from_shell"
        command.send(:load_dotenv!)
        expect(ENV.fetch("INQUIREX_TEST_VAR")).to eq("from_shell")
      ensure
        ENV.delete("INQUIREX_TEST_VAR")
      end
    end
  end
end
# rubocop:enable RSpec/AnyInstance, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
