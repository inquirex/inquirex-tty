# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Prints inquirex-tty and inquirex gem versions to stdout.
      class Version < Dry::CLI::Command
        desc "Print version information"

        # Prints the version of this gem and of the core inquirex gem.
        # Any CLI options are accepted and ignored.
        #
        # @return [void]
        def call(**)
          puts "inquirex-tty #{Inquirex::TTY::VERSION}"
          puts "inquirex     #{Inquirex::VERSION}"
        end
      end
    end
  end
end
