# frozen_string_literal: true

module Inquirex
  module TTY
    module Commands
      # Validates a flow definition file: start step exists, all transition targets
      # are known, and every step is reachable from the start step.
      class Validate < Dry::CLI::Command
        desc "Validate a flow definition file"

        argument :flow_file, required: true, desc: "Path to flow definition (.rb file)"

        # @param flow_file [String]
        # @return [void]
        def call(flow_file:, **)
          definition = FlowLoader.load(flow_file)
          errors     = validate_definition(definition)

          if errors.empty?
            print_success(definition)
          else
            print_errors(errors)
            exit 1
          end
        rescue Inquirex::TTY::Error => e
          warn "Error: #{e.message}"
          exit 1
        rescue Inquirex::Errors::Error => e
          warn "Definition error: #{e.message}"
          exit 1
        end

        private

        def print_success(definition)
          puts "Flow definition is valid!"
          puts "  ID:          #{definition.id || "(none)"}"
          puts "  Version:     #{definition.version}"
          puts "  Start step:  #{definition.start_step_id}"
          puts "  Total steps: #{definition.step_ids.length}"
          puts "  Steps:       #{definition.step_ids.join(", ")}"
          print_meta(definition.meta) if definition.meta && !definition.meta.empty?
        end

        def print_meta(meta)
          puts "  Title:    #{meta[:title]}"    if meta[:title]
          puts "  Subtitle: #{meta[:subtitle]}" if meta[:subtitle]
        end

        def print_errors(errors)
          warn "Flow definition has #{errors.length} error(s):"
          errors.each { |e| warn "  - #{e}" }
        end

        def validate_definition(definition)
          errors = []
          validate_start_step(definition, errors)
          validate_transition_targets(definition, errors)
          validate_reachability(definition, errors)
          errors
        end

        def validate_start_step(definition, errors)
          return if definition.step_ids.include?(definition.start_step_id)

          errors << "Start step :#{definition.start_step_id} not found in steps"
        end

        def validate_transition_targets(definition, errors)
          definition.step_ids.each do |step_id|
            step = definition.step(step_id)
            step.transitions.each do |transition|
              next if definition.step_ids.include?(transition.target)

              errors << "Step :#{step_id} transitions to unknown step :#{transition.target}"
            end
          end
        end

        def validate_reachability(definition, errors)
          reachable = find_reachable_steps(definition)
          orphans   = definition.step_ids - reachable
          orphans.each { |o| errors << "Step :#{o} is unreachable from :#{definition.start_step_id}" }
        end

        def find_reachable_steps(definition)
          visited = Set.new
          queue   = [definition.start_step_id]
          known   = definition.step_ids

          until queue.empty?
            current = queue.shift
            next if visited.include?(current)

            visited << current
            next unless known.include?(current)

            definition.step(current).transitions.each do |t|
              queue << t.target if known.include?(t.target)
            end
          end

          visited.to_a
        end
      end
    end
  end
end
