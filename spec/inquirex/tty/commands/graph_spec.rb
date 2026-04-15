# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "tmpdir"

# Stubbing `system` on the subject is the right tool here — the command
# shells out to mermaid-cli and we do not want the real binary on CI.
# rubocop:disable RSpec/SubjectStub
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

    context "with --format image" do
      let(:tmpfile) { Tempfile.new(["graph", ".png"]) }

      after { tmpfile.close; tmpfile.unlink }

      before do
        # Fake a working mermaid-cli install so the CLI never shells out.
        allow(command).to receive(:system).and_return(true)
      end

      it "invokes mmdc and writes the image path" do
        expect do
          command.call(flow_file: hello_flow_path, format: "image", output: tmpfile.path)
        end.to output(/Diagram written to .+\.png/).to_stderr
        expect(command).to have_received(:system).with(/mmdc /).at_least(:once)
      end

      it "opens the file when --open is true" do
        expect do
          command.call(flow_file: hello_flow_path, format: "image", output: tmpfile.path, open: true)
        end.to output(/Diagram written to/).to_stderr
        expect(command).to have_received(:system).with(/^open /)
      end
    end

    context "with --format both" do
      let(:dir) { Dir.mktmpdir("graph-both") }

      after { FileUtils.remove_entry(dir) }

      before { allow(command).to receive(:system).and_return(true) }

      it "writes both the source and the image" do
        expect do
          command.call(flow_file: hello_flow_path, format: "both", output: dir)
        end.to output(/Diagram written to/).to_stderr
        expect(File).to exist(File.join(dir, "hello_flow.mmd"))
      end
    end

    context "when mmdc is not installed and npm install fails" do
      let(:tmpfile) { Tempfile.new(["graph", ".png"]) }

      after { tmpfile.close; tmpfile.unlink }

      before do
        # command_available? and npm install both fail.
        allow(command).to receive(:system).and_return(false)
      end

      it "exits 1 and tells the user how to install" do
        expect do
          command.call(flow_file: hello_flow_path, format: "image", output: tmpfile.path)
        rescue SystemExit
          # expected
        end.to output(/Could not install mermaid-cli/).to_stderr
      end
    end

    context "when the mmdc invocation itself fails" do
      let(:tmpfile) { Tempfile.new(["graph", ".png"]) }

      after { tmpfile.close; tmpfile.unlink }

      before do
        # command_available? returns true, mmdc returns false.
        call_counter = 0
        allow(command).to receive(:system) do |_cmd|
          call_counter += 1
          # First call is `command -v mmdc` — succeed; everything after fails.
          call_counter == 1
        end
      end

      it "exits 1 with a helpful mmdc error" do
        expect do
          command.call(flow_file: hello_flow_path, format: "image", output: tmpfile.path)
        rescue SystemExit
          # expected
        end.to output(/Failed to generate image/).to_stderr
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
# rubocop:enable RSpec/SubjectStub
