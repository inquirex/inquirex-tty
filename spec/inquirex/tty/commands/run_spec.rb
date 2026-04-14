# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inquirex::TTY::Commands::Run do
  subject(:command) { described_class.new }

  let(:hello_flow_path) { File.expand_path("../../../fixtures/hello_flow.rb", __dir__) }

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
    end
  end
end
