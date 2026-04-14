# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Inquirex::TTY::OutputPath do
  let(:flow_file) { "/tmp/flows/08_tax_preparer.rb" }

  describe ".resolve" do
    context "when output is nil" do
      it "returns nil (caller writes to stdout)" do
        expect(described_class.resolve(flow_file, nil, ".json")).to be_nil
      end
    end

    context "when output is an empty string" do
      it "returns nil" do
        expect(described_class.resolve(flow_file, "", ".json")).to be_nil
      end
    end

    context "when output is an existing directory" do
      it "joins directory with flow basename + extension" do
        Dir.mktmpdir("output-path") do |dir|
          expect(described_class.resolve(flow_file, dir, ".json")).to eq(
            File.join(dir, "08_tax_preparer.json")
          )
        end
      end

      it "works for yaml too" do
        Dir.mktmpdir("output-path") do |dir|
          expect(described_class.resolve(flow_file, dir, ".yml")).to eq(
            File.join(dir, "08_tax_preparer.yml")
          )
        end
      end
    end

    context "when output is a filename with no extension" do
      it "appends the extension" do
        expect(described_class.resolve(flow_file, "/tmp/out", ".json")).to eq("/tmp/out.json")
      end
    end

    context "when output is a filename with a matching extension" do
      it "returns it unchanged (same extension)" do
        expect(described_class.resolve(flow_file, "/tmp/out.json", ".json")).to eq("/tmp/out.json")
      end
    end

    context "when output is a filename with a different extension" do
      it "substitutes the extension" do
        expect(described_class.resolve(flow_file, "/tmp/out.txt", ".json")).to eq("/tmp/out.json")
      end
    end
  end

  describe ".resolve_with_default" do
    context "when output is nil" do
      it "returns <basename>.<ext> in cwd" do
        expect(described_class.resolve_with_default(flow_file, nil, ".png")).to eq("08_tax_preparer.png")
      end
    end

    context "when output is a filename" do
      it "behaves like .resolve" do
        expect(described_class.resolve_with_default(flow_file, "/tmp/out", ".png")).to eq("/tmp/out.png")
      end
    end
  end

  describe ".flow_basename" do
    it "strips the extension" do
      expect(described_class.flow_basename("/some/path/my_flow.rb")).to eq("my_flow")
    end

    it "handles paths with multiple dots" do
      expect(described_class.flow_basename("/some/path/my.flow.rb")).to eq("my.flow")
    end
  end
end
