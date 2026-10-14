# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# `allow_any_instance_of` is the cleanest lever for objects the CLI creates
# internally (Engine, LLM adapters, TTY::Font) — we would otherwise have to
# redesign the command for DI just for tests.
# rubocop:disable RSpec/AnyInstance, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups, RSpec/SubjectStub
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
        # Never let the metadata probes touch the real network in specs
        allow(command).to receive_messages(public_ip: "203.0.113.7", local_ip: "192.168.1.10")
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

        it "attaches completion metadata to the answers" do
          command.call(flow_file: hello_flow_path, output: tmpfile.path)
          metadata = JSON.parse(File.read(tmpfile.path)).dig("answers", "completion_metadata")
          expect(metadata).to include(
            "engine"         => "inquirex-tty",
            "engine_version" => Inquirex::TTY::VERSION,
            "local_ip"       => "192.168.1.10",
            "public_ip"      => "203.0.113.7"
          )
          expect(metadata["uname"]).to include("sysname", "machine")
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
        allow(command).to receive_messages(public_ip: nil, local_ip: nil)
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

  describe "results channel" do
    let(:answers_file) { Tempfile.new(["answers", ".json"]) }

    # Runs the block with stdout and stderr captured separately.
    def capture
      out = StringIO.new
      err = StringIO.new
      original = [$stdout, $stderr]
      $stdout = out
      $stderr = err
      yield
      [out.string, err.string]
    ensure
      $stdout, $stderr = original
    end

    before do
      allow(command).to receive_messages(public_ip: "203.0.113.7", local_ip: "192.168.1.10")
      answers_file.write(JSON.generate("name" => "Alan Turing"))
      answers_file.flush
    end

    after { answers_file.close! }

    context "when run interactively" do
      let(:prompt)   { instance_double(TTY::Prompt) }
      let(:renderer) { Inquirex::TTY::Renderer.new(prompt:) }

      before do
        allow(Inquirex::TTY::Renderer).to receive(:new).and_return(renderer)
        allow(prompt).to receive(:keypress)
        allow(prompt).to receive(:ask).and_return("Alan Turing")
      end

      it "prints only the results on stdout, and everything else on stderr" do
        out, err = capture { command.call(flow_file: hello_flow_path) }

        expect(JSON.parse(out).dig("answers", "name")).to eq("Alan Turing")
        expect(err).to match(/Step 1: .*name/)
        expect(err).not_to include('"answers"')
      end
    end

    context "when run headless" do
      before do
        allow(TTY::Prompt).to receive(:new).and_raise("a headless run built a TTY::Prompt")
        allow(Inquirex::TTY::Renderer).to receive(:new).and_raise("a headless run built a Renderer")
      end

      it "runs from --answers and prints the results on stdout" do
        out, err = capture { command.call(flow_file: hello_flow_path, answers: answers_file.path) }

        results = JSON.parse(out)
        expect(results).to include("flow_file" => hello_flow_path, "path_taken" => %w[name farewell])
        expect(results.dig("answers", "name")).to eq("Alan Turing")
        expect(err).to be_empty
      end

      it "never asks the network for a public IP" do
        capture { command.call(flow_file: hello_flow_path, answers: answers_file.path) }
        expect(command).not_to have_received(:public_ip)
      end

      it "writes the results to -o FILE and nothing to stdout" do
        Tempfile.create(["results", ".json"]) do |file|
          out, err = capture { command.call(flow_file: hello_flow_path, answers: answers_file.path, output: file.path) }

          expect(out).to be_empty
          expect(JSON.parse(File.read(file.path)).dig("answers", "name")).to eq("Alan Turing")
          expect(err).to include("Results saved to #{file.path}")
        end
      end

      it "treats -o - as stdout" do
        out, = capture { command.call(flow_file: hello_flow_path, answers: answers_file.path, output: "-") }
        expect(JSON.parse(out).dig("answers", "name")).to eq("Alan Turing")
      end

      it "exits non-zero naming a required step --yes cannot answer" do
        out, err = capture do
          expect { command.call(flow_file: hello_flow_path, yes: true) }
            .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
        end

        expect(out).to be_empty
        expect(err).to include(":name")
      end

      it "exits non-zero on an answers file it cannot read" do
        _, err = capture do
          expect { command.call(flow_file: hello_flow_path, answers: "answers.txt") }
            .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
        end

        expect(err).to include("must be .json, .yml or .yaml")
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
# rubocop:enable RSpec/AnyInstance, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups, RSpec/SubjectStub
