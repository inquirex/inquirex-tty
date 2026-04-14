# frozen_string_literal: true

require "simplecov"
require "coverage/badge"

SimpleCov.start do
  minimum_coverage 80
  add_filter "/spec/"
  self.formatters = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      Coverage::Badge::Formatter
    ]
  )
end

SimpleCov.at_exit do
  SimpleCov.result.format!
  # rubocop: disable RSpec/Output
  puts "Coverage: #{SimpleCov.result.covered_percent.round(2)}%"
  # rubocop: enable RSpec/Output
  FileUtils.mv("coverage/badge.svg", "docs/badges/coverage_badge.svg")
end

require "inquirex/tty"
require "rspec/its"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
