# frozen_string_literal: true

module Inquirex
  module TTY
    # Loads a flow definition from a Ruby file by evaluating it in a top-level
    # binding. The file is expected to call +Inquirex.define+ and return an
    # +Inquirex::Definition+.
    class FlowLoader
      # @param path [String] path to a .rb flow definition file
      # @return [Inquirex::Definition]
      # @raise [Inquirex::TTY::Error] if file is missing, not .rb, or has syntax errors
      def self.load(path)
        new(path).load
      end

      # @param path [String] path (will be expanded)
      def initialize(path)
        @path = File.expand_path(path)
        validate_path!
      end

      # @return [Inquirex::Definition]
      # @raise [Inquirex::TTY::Error] on syntax error
      def load
        content = File.read(@path)
        # rubocop:disable Security/Eval
        eval(content, TOPLEVEL_BINDING.dup, @path, 1)
        # rubocop:enable Security/Eval
      rescue SyntaxError => e
        raise Inquirex::TTY::Error, "Syntax error in #{@path}: #{e.message}"
      end

      private

      def validate_path!
        raise Inquirex::TTY::Error, "File not found: #{@path}" unless File.exist?(@path)
        raise Inquirex::TTY::Error, "Not a .rb file: #{@path}" unless @path.end_with?(".rb")
      end
    end
  end
end
