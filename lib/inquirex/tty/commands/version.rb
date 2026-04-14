# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Prints inquirex-tty, inquirex, and inquirex-ui gem versions to stdout.
      class Version < Dry::CLI::Command
        desc "Print version information"

        # @param **_ [Hash] ignored options
        # @return [void]
        def call(**)
          puts "inquirex-tty #{Inquirex::TTY::VERSION}"
          puts "inquirex     #{Inquirex::VERSION}"
          puts "inquirex-ui  #{Inquirex::UI::VERSION}"
        end
      end
    end
  end
end
