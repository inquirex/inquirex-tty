# frozen_string_literal: true

require_relative "lib/inquirex/tty/version"

Gem::Specification.new do |spec|
  spec.name = "inquirex-tty"
  spec.version = Inquirex::TTY::VERSION
  spec.authors = ["Konstantin Gredeskoul"]
  spec.email = ["kigster@gmail.com"]

  spec.summary = "Terminal adapter for Inquirex flows — interactive TTY wizard via tty-prompt"
  spec.description = "Renders Inquirex::UI flow definitions as interactive ANSI terminal wizards " \
                     "using tty-prompt, tty-box, and tty-font. Provides a dry-cli command suite: " \
                     "run, validate, graph, open-graph, version."
  spec.homepage = "https://github.com/flowengine-rb/inquirex-tty"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/inquirex/inquirex-tty"
  spec.metadata["changelog_uri"] = "https://github.com/inquirex/inquirex-tty/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "dry-cli",     "~> 1.0"
  spec.add_dependency "inquirex",    "~> 0.2"
  spec.add_dependency "inquirex-ui", "~> 0.2"
  spec.add_dependency "pastel",      "~> 0.8"
  spec.add_dependency "tty-box",     "~> 0.7"
  spec.add_dependency "tty-font",    "~> 0.5"
  spec.add_dependency "tty-prompt",  "~> 0.23"
  spec.add_dependency "tty-screen",  "~> 0.8"
end
