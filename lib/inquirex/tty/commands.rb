# frozen_string_literal: true

module Inquirex
  module TTY
    # Dry::CLI registry for inquirex-tty subcommands.
    # UIHelper is mixed into every command so box/sep/next_step are available.
    module Commands
      extend Dry::CLI::Registry

      ::Dry::CLI::Command.include(UIHelper)

      register "run",        Run
      register "graph",      Graph
      register "open-graph", OpenGraph
      register "validate",   Validate
      register "version",    Version
    end
  end
end
