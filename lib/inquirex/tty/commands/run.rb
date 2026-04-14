# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Runs a flow definition interactively via TTY prompts and writes the
      # collected answers (plus metadata) as JSON to stderr or a file.
      class Run < Dry::CLI::Command
        desc "Run a flow definition interactively"

        argument :flow_file, required: true, desc: "Path to flow definition (.rb file)"
        option :output, aliases: ["-o"], desc: "Write JSON results to this file instead of stderr"

        # @param flow_file [String]
        # @param options [Hash]
        # @return [void]
        def call(flow_file:, **options)
          engine = run_flow(flow_file)
          json   = JSON.pretty_generate(build_result(flow_file, engine))

          if options[:output]
            File.write(options[:output], json)
            puts "\nResults saved to #{options[:output]}"
          else
            $stderr.puts json # rubocop:disable Style/StderrPuts
          end
        rescue Inquirex::TTY::Error => e
          error(e.message)
          exit 1
        rescue Inquirex::Errors::Error => e
          error("Engine error: #{e.message}")
          exit 1
        end

        private

        # @param flow_file [String]
        # @return [Inquirex::Engine]
        def run_flow(flow_file)
          definition = FlowLoader.load(flow_file)
          engine     = Inquirex::Engine.new(definition)
          renderer   = Renderer.new

          show_banner(definition)

          until engine.finished?
            step = engine.current_step
            next_step(engine.current_step_id, engine.history.length + 1)

            if step.display?
              renderer.render(step)
              engine.advance
            else
              engine.answer(renderer.render(step))
            end
          end

          engine
        end

        # @param definition [Inquirex::Definition]
        # @return [void]
        def show_banner(definition)
          title = definition.meta&.fetch(:title, nil) || "Inquirex"
          font  = ::TTY::Font.new(:standard)
          puts pastel.bright_green(font.write(title.upcase))
          sep(:green, "━")
        rescue StandardError
          puts box(definition.meta&.fetch(:title, nil) || "Inquirex Wizard")
        end

        # @param flow_file [String]
        # @param engine [Inquirex::Engine]
        # @return [Hash]
        def build_result(flow_file, engine)
          {
            flow_file:       flow_file,
            path_taken:      engine.history,
            answers:         engine.answers,
            steps_completed: engine.history.length,
            completed_at:    Time.now.iso8601
          }
        end
      end
    end
  end
end
