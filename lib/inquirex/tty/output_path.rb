# frozen_string_literal: true

module Inquirex
  module TTY
    # Shared output path resolution for commands that accept an `-o/--output` option.
    #
    # Rules:
    #   - nil or empty output          → nil (caller should write to stdout)
    #   - output is an existing dir    → <dir>/<flow-basename>.<ext>
    #   - output has an extension      → <output> with its extension replaced by .<ext>
    #   - output has no extension      → <output>.<ext>
    #
    # For commands that must always write to a file (e.g. images that cannot go
    # to stdout), use {.resolve_with_default}, which falls back to
    # `<flow-basename>.<ext>` in the current directory.
    module OutputPath
      module_function

      # Resolves an output path, returning nil when the caller should use stdout.
      #
      # @param flow_file [String] source .rb flow file (basename used for defaults)
      # @param output    [String, nil] value of the --output option
      # @param extension [String] including leading dot, e.g. ".json"
      # @return [String, nil]
      def resolve(flow_file, output, extension)
        return nil if output.nil? || output.to_s.empty?
        return File.join(output, "#{flow_basename(flow_file)}#{extension}") if File.directory?(output)

        with_default_extension(output, extension)
      end

      # Resolves an output path, falling back to "<basename>.<ext>" in cwd when
      # no --output was given. For commands where stdout is not an option.
      #
      # @param flow_file [String]
      # @param output    [String, nil]
      # @param extension [String]
      # @return [String]
      def resolve_with_default(flow_file, output, extension)
        resolve(flow_file, output, extension) || "#{flow_basename(flow_file)}#{extension}"
      end

      # The flow file's basename without its extension.
      #
      # @param flow_file [String]
      # @return [String]
      def flow_basename(flow_file)
        File.basename(flow_file, File.extname(flow_file))
      end

      # Ensures `path` ends with the given extension. If the path has no
      # extension, appends it. If it has one, replaces it.
      #
      # @param path      [String]
      # @param extension [String] including leading dot
      # @return [String]
      def with_default_extension(path, extension)
        if File.extname(path).empty?
          "#{path}#{extension}"
        else
          path.sub(%r{\.[^/.]+\z}, extension)
        end
      end
    end
  end
end
