# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "tmpdir"
require "json"
require "yaml"

RSpec.describe Inquirex::TTY::Commands::Export do
  subject(:command) { described_class.new }

  let(:hello_flow_path) { File.expand_path("../../../fixtures/hello_flow.rb", __dir__) }

  describe "#call" do
    context "with no --output and default format (json)" do
      it "prints pretty JSON to stdout" do
        expect { command.call(flow_file: hello_flow_path) }
          .to output(/"start":/).to_stdout
      end

      it "produces valid JSON" do
        output = capture_stdout { command.call(flow_file: hello_flow_path) }
        expect { JSON.parse(output) }.not_to raise_error
      end
    end

    context "with --format yaml and no --output" do
      it "prints YAML to stdout" do
        expect { command.call(flow_file: hello_flow_path, format: "yaml") }
          .to output(/^---/).to_stdout
      end

      it "accepts yml as an alias for yaml" do
        expect { command.call(flow_file: hello_flow_path, format: "yml") }
          .to output(/^---/).to_stdout
      end
    end

    context "with --output pointing to a directory" do
      it "writes JSON to <dir>/<basename>.json" do
        Dir.mktmpdir("export-dir") do |dir|
          command.call(flow_file: hello_flow_path, output: dir)
          expected = File.join(dir, "hello_flow.json")
          expect(File).to exist(expected)
          expect { JSON.parse(File.read(expected)) }.not_to raise_error
        end
      end

      it "writes YAML to <dir>/<basename>.yml when format is yml" do
        Dir.mktmpdir("export-dir") do |dir|
          command.call(flow_file: hello_flow_path, output: dir, format: "yml")
          expected = File.join(dir, "hello_flow.yml")
          expect(File).to exist(expected)
          parsed = YAML.safe_load_file(expected, permitted_classes: [Symbol])
          expect(parsed).to include("start")
        end
      end
    end

    context "with --output pointing to a filename" do
      it "appends .json extension when missing" do
        Dir.mktmpdir("export-file") do |dir|
          target = File.join(dir, "my-output")
          command.call(flow_file: hello_flow_path, output: target)
          expect(File).to exist("#{target}.json")
        end
      end

      it "uses the filename as-is when extension matches" do
        Dir.mktmpdir("export-file") do |dir|
          target = File.join(dir, "my-output.json")
          command.call(flow_file: hello_flow_path, output: target)
          expect(File).to exist(target)
        end
      end
    end

    context "when the flow file does not exist" do
      it "exits with status 1" do
        expect { command.call(flow_file: "/no/such/file.rb") }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
