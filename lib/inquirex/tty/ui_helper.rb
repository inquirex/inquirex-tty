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

        # Module hook that installs the UI helpers on the including class:
        # +tty_box+, +tty_screen+, +pastel+, the TTY::Box wrappers (+frame+,
        # +info+, +success+, +error+, +warning+), the +width+ delegator, and
        # the +box+ / +next_step+ / +sep+ convenience methods.
        #
        # @param base [Class, Module] the class or module including UIHelper
        # @return [void]
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
            #
            # @param text [String] text to display inside the box
            # @param title [String, nil] optional title on the top border
            # @param bg [Symbol] background color name
            # @param fg [Symbol] foreground color name
            # @return [void]
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
            #
            # @param step_id [Symbol, String] id of the step about to run
            # @param step_number [Integer] 1-based position in the flow
            # @return [void]
            def next_step(step_id, step_number)
              puts pastel.yellow("Step #{step_number}: #{step_id}")
              sep(:yellow, "━")
            end

            # Print a full-width separator in the given color.
            #
            # @param color [Symbol] Pastel color name
            # @param char [String] character repeated across the line
            # @return [void]
            def sep(color = :yellow, char = "━")
              puts pastel.send(color, char * 80)
            end
          end
        end
      end
    end
  end
end
