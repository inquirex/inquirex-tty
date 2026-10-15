# frozen_string_literal: true

# A library the gem requires at load time must ship with Ruby or be a declared
# runtime dependency. Ruby 4.1 stopped shipping prism as a default gem, and
# inquirex 0.11.0 reached it only through rubocop's development dependency:
# its suite stayed green while every consumer's `require "inquirex"` raised
# LoadError. This spec reads lib/ for what it requires instead of trusting a
# hand-kept list, so a new require cannot slip past it.
RSpec.describe "inquirex-tty.gemspec" do
  let(:root) { File.expand_path("../../..", __dir__) }
  let(:gemspec) { Gem::Specification.load(File.join(root, "inquirex-tty.gemspec")) }
  let(:runtime) { gemspec.runtime_dependencies.map(&:name) }

  # Every feature lib/ requires, other than this gem family's own files.
  let(:features) do
    Dir[File.join(root, "lib/**/*.rb")]
      .flat_map { |file| File.read(file).scan(/^\s*require\s+["']([^"']+)["']/).flatten }
      .uniq
      .reject { |feature| feature.start_with?("inquirex") }
  end

  # Ships with the running Ruby: default gems and extensions install their
  # files into rubylibdir/rubyarchdir; bundled gems (ostruct, and prism on
  # Ruby 4.1) do not.
  def shipped_with_ruby?(feature)
    [RbConfig::CONFIG["rubylibdir"], RbConfig::CONFIG["rubyarchdir"]].any? do |dir|
      Dir.glob(File.join(dir, "#{feature}{.rb,.bundle,.so}")).any?
    end
  end

  it "declares a runtime dependency for every library lib/ requires that Ruby does not ship" do
    undeclared = features.reject { |feature| shipped_with_ruby?(feature) }.reject do |feature|
      runtime.include?(Gem::Specification.find_by_path(feature)&.name)
    end

    expect(undeclared).to be_empty
  end

  it "declares ostruct, a bundled gem since Ruby 3.5" do
    expect(runtime).to include("ostruct")
  end

  it "depends on the core and LLM gems at the version it is released with" do
    requirements = gemspec.runtime_dependencies.to_h { |dep| [dep.name, dep.requirement.to_s] }
    expect(requirements).to include("inquirex" => "~> 0.12", "inquirex-llm" => "~> 0.12")
  end
end
