# frozen_string_literal: true

module Inquirex
  module TTY
    # Reads the preset answers for `inquirex-tty run --answers FILE`.
    #
    # The file maps step ids to answers, `{step_id: value}`, in JSON or YAML;
    # the extension decides which. Values are passed to the engine as written:
    # a multi-select takes a list of option values, not their labels.
    #
    # @example answers.yml
    #   income_types: [w2, rental]
    #   client_name: Alan Turing
    #   client_email: alan.turing@manchester.edu
    module AnswersFile
      # @return [Hash{String => Symbol}] extension to format
      FORMATS = { ".json" => :json, ".yml" => :yaml, ".yaml" => :yaml }.freeze

      module_function

      # @param path [String]
      # @return [Hash{String => Object}] answers keyed by step id
      # @raise [Inquirex::TTY::Error] when the file is missing, has another
      #   extension, does not parse, or is not a mapping
      def load(path)
        format = FORMATS[File.extname(path).downcase]
        raise Error, "Answers file must be .json, .yml or .yaml: #{path}" unless format
        raise Error, "Answers file not found: #{path}" unless File.file?(path)

        answers = parse(File.read(path), format)
        raise Error, "Answers file must map step ids to answers: #{path}" unless answers.is_a?(Hash)

        answers
      rescue JSON::ParserError, Psych::Exception => e
        raise Error, "Cannot parse answers file #{path}: #{e.message}"
      end

      # safe_load: an answers file is data, so no YAML tags that build objects.
      #
      # @param text [String]
      # @param format [Symbol] :json or :yaml
      # @return [Object]
      def parse(text, format)
        format == :json ? JSON.parse(text) : YAML.safe_load(text)
      end
    end
  end
end
