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
          load_dotenv!
          definition = FlowLoader.load(flow_file)
          engine     = Inquirex::Engine.new(definition)
          renderer   = Renderer.new
          adapter    = build_llm_adapter

          show_banner(definition)

          until engine.finished?
            step = engine.current_step
            next_step(engine.current_step_id, engine.history.length + 1)

            if step.respond_to?(:llm_verb?) && step.llm_verb?
              run_llm_step(engine, step, adapter, renderer)
            elsif step.display?
              renderer.render(step)
              engine.advance
            else
              engine.answer(renderer.render(step))
            end
          end

          engine
        end

        # Calls the LLM adapter for a clarify/describe/summarize/detour step,
        # stores the result as the step's answer, and for clarify verbs splats
        # extracted fields into top-level answers via Engine#prefill! so that
        # downstream `skip_if not_empty(:key)` rules will fire.
        def run_llm_step(engine, step, adapter, renderer)
          renderer.thinking("🧠 Thinking — asking #{adapter_label(adapter)} to extract structured data…")
          result = adapter.call(step, engine.answers)
          engine.answer(result)
          if step.verb == :clarify && result.is_a?(Hash)
            engine.prefill!(result)
            renderer.show_extraction(result)
          else
            puts "\n#{result.is_a?(String) ? result : JSON.pretty_generate(result)}\n"
          end
        rescue StandardError => e
          error("LLM step #{step.id} failed: #{e.class}: #{e.message}")
          raise
        end

        # Adapter preference order (first match wins):
        #   INQUIREX_LLM_ADAPTER=null         → NullAdapter (forced offline)
        #   INQUIREX_LLM_ADAPTER=anthropic    → AnthropicAdapter (fails if no key)
        #   INQUIREX_LLM_ADAPTER=openai       → OpenAIAdapter (fails if no key)
        #   ANTHROPIC_API_KEY present         → AnthropicAdapter
        #   OPENAI_API_KEY present            → OpenAIAdapter
        #   otherwise                         → NullAdapter
        def build_llm_adapter
          forced = ENV["INQUIREX_LLM_ADAPTER"].to_s.downcase
          return Inquirex::LLM::NullAdapter.new      if forced == "null"
          return Inquirex::LLM::AnthropicAdapter.new if forced == "anthropic"
          return Inquirex::LLM::OpenAIAdapter.new    if forced == "openai"

          if env_key?("ANTHROPIC_API_KEY") && defined?(Inquirex::LLM::AnthropicAdapter)
            Inquirex::LLM::AnthropicAdapter.new
          elsif env_key?("OPENAI_API_KEY") && defined?(Inquirex::LLM::OpenAIAdapter)
            Inquirex::LLM::OpenAIAdapter.new
          else
            Inquirex::LLM::NullAdapter.new
          end
        end

        def env_key?(name)
          v = ENV.fetch(name, nil)
          !v.nil? && !v.empty?
        end

        def adapter_label(adapter)
          case adapter
          when Inquirex::LLM::AnthropicAdapter then "Claude"
          when Inquirex::LLM::OpenAIAdapter    then "GPT"
          else "the null adapter"
          end
        rescue NameError
          "the null adapter"
        end

        # Minimal .env loader. Walks up from the cwd and the flow file's
        # directory, loading every .env found along the way. Later loads do
        # not overwrite earlier values, and nothing overrides keys already
        # set in the real environment.
        def load_dotenv!
          seen = {}
          [Dir.pwd, File.dirname(File.expand_path(ARGV.last.to_s))].uniq.each do |start|
            walk_ancestors(start).each do |dir|
              path = File.join(dir, ".env")
              next if seen[path] || !File.file?(path)

              seen[path] = true
              load_env_file(path)
            end
          end
        end

        def walk_ancestors(dir)
          ancestors = []
          current = File.expand_path(dir)
          loop do
            ancestors << current
            parent = File.dirname(current)
            break if parent == current

            current = parent
          end
          ancestors
        end

        def load_env_file(path)
          File.foreach(path) do |line|
            next if line.strip.empty? || line.start_with?("#")

            key, _, value = line.strip.partition("=")
            next if key.empty?
            # Preserve shell-set values, but fill in keys that are unset or
            # set to the empty string.
            next if ENV.key?(key) && !ENV[key].to_s.empty?

            ENV[key] = value.gsub(/\A["']|["']\z/, "")
          end
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
