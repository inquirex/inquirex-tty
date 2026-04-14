# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "tmpdir"

RSpec.describe Inquirex::TTY::Commands::Graph do
  subject(:command) { described_class.new }

  let(:hello_flow_path) { File.expand_path("../../../fixtures/hello_flow.rb", __dir__) }

  describe "#call" do
    context "with source format (default)" do
      it "outputs Mermaid source to stdout" do
        expect { command.call(flow_file: hello_flow_path) }
          .to output(/flowchart/).to_stdout
      end

      it "includes step ids in the diagram" do
        expect { command.call(flow_file: hello_flow_path) }
          .to output(/name/).to_stdout
      end
    end

    context "with --output file" do
      let(:tmpfile) { Tempfile.new(["graph", ".mmd"]) }

      after { tmpfile.close; tmpfile.unlink }

      it "writes Mermaid source to the file" do
        command.call(flow_file: hello_flow_path, output: tmpfile.path)
        expect(File.read(tmpfile.path)).to match(/flowchart/)
      end
    end

    context "when the file does not exist" do
      it "exits with status 1" do
        expect { command.call(flow_file: "/no/such/file.rb") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end
  end

  describe "output path resolution (via OutputPath)" do
    let(:flow_file) { "/tmp/flows/some.flow.definition.json" }

    context "when output points to an existing directory" do
      it "derives source and image filenames from flow_file basename" do
        Dir.mktmpdir("graph-output") do |dir|
          expect(Inquirex::TTY::OutputPath.resolve(flow_file, dir, ".mmd")).to eq(
            File.join(dir, "some.flow.definition.mmd")
          )
          expect(Inquirex::TTY::OutputPath.resolve_with_default(flow_file, dir, ".png")).to eq(
            File.join(dir, "some.flow.definition.png")
          )
        end
      end
    end

    context "when output points to a filename" do
      it "uses that filename and substitutes extension per output type" do
        output = "/tmp/custom-name.anything"

        expect(Inquirex::TTY::OutputPath.resolve(flow_file, output, ".mmd")).to eq("/tmp/custom-name.mmd")
        expect(Inquirex::TTY::OutputPath.resolve_with_default(flow_file, output, ".png")).to eq("/tmp/custom-name.png")
      end
    end
  end
end
