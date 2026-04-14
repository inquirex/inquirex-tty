# frozen_string_literal: true

module Inquirex
  module TTY
    # Mixin providing TTY::Box, Pastel, and screen helpers to CLI commands
    # and the Renderer. Defines +box+, +sep+, +next_step+, +frame+, +info+,
    # +success+, +error+, +warning+, and +width+ on the including class.
    module UIHelper
      class << self
        # @return [Pastel] shared Pastel instance
        def pastel
          @pastel ||= Pastel.new
        end

        def included(base)
          base.extend(Forwardable)
          base.define_method(:tty_box)    { ::TTY::Box }
          base.define_method(:tty_screen) { ::TTY::Screen }
          base.define_method(:pastel)     { ::Inquirex::TTY::UIHelper.pastel }

          %i[frame info success error].each do |method|
            base.define_method(method) { |*args, **kwargs| puts ::TTY::Box.send(method, *args, **kwargs) }
          end
          base.define_method(:warning) { |*args, **kwargs| puts ::TTY::Box.send(:warn, *args, **kwargs) }

          base.def_delegators :tty_screen, :width

          base.class_eval do
            # Draw a bordered box with optional title.
            def box(text, title: nil, bg: :green, fg: :white) # rubocop:disable Naming/MethodParameterName
              w = [width, 80].min
              args = {
                width:   w,
                padding: { top: 0, bottom: 0, left: 1, right: 1 },
                align:   :center,
                style:   { fg: fg, bg: bg,
                         border: { type: :thin, fg: fg, bg: bg } }
              }
              args[:title] = { top_left: title } if title
              frame(text, **args)
            end

            # Print step progress and separator.
            def next_step(step_id, step_number)
              puts pastel.yellow("Step #{step_number}: #{step_id}")
              sep(:yellow, "━")
            end

            # Print a full-width separator in the given color.
            def sep(color = :yellow, char = "━")
              puts pastel.send(color, char * 80)
            end
          end
        end
      end
    end
  end
end
