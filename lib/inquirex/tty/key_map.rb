# frozen_string_literal: true

module Inquirex
  module TTY
    # Raised out of a tty-prompt widget when the user presses a navigation
    # key, so whichever widget is open (ask, select, multi_select, yes?)
    # unwinds without returning an answer. tty-prompt offers no hook that
    # aborts a question, and a subclass per widget would mean overriding the
    # read loop of each one; one exception covers them all.
    class Navigation < StandardError
      # @return [Symbol] :back, :skip or :help
      attr_reader :action

      # @param action [Symbol] :back, :skip or :help
      def initialize(action)
        @action = action
        super("navigation: #{action}")
      end
    end

    # The keys that navigate a TTY run, as a tty-reader listener that turns
    # them into {Navigation} exceptions while a collecting prompt is open.
    #
    # Backspace and "?" are also editing keys, so in a text answer they
    # navigate only while the answer is empty: Backspace on an empty line
    # goes back, Backspace after text deletes a character, and "what?" types
    # a question mark. Lists have no text, so there they always navigate.
    # Ctrl-B goes back from anywhere: tty-reader maps byte 0x02 to :ctrl_b in
    # every terminal and tty-prompt binds nothing to it.
    #
    # tty-reader reports a key after it has edited the line, so the listener
    # cannot ask "was the line empty?" directly. It keeps its own count of the
    # characters typed instead, from how much each event's line grew or
    # shrank. A pre-filled answer is a tty-prompt +default:+, shown beside
    # the question rather than typed into the line, so every line starts empty.
    #
    # @example Wrap a prompt call
    #   prompt.subscribe(KeyMap.new(can_back: engine.can_back?))
    class KeyMap
      # tty-reader key names that edit text and go back on an empty answer.
      BACKSPACE = %i[backspace ctrl_h].freeze

      # Every navigation key, for the help box.
      BINDINGS = [
        ["Enter",      "submit the answer (an empty answer keeps the one shown)"],
        ["Backspace",  "go back to the previous question (on an empty answer)"],
        ["Ctrl-B",     "go back to the previous question"],
        ["Ctrl-S",     "skip the question (optional questions only)"],
        ["↑ ↓  Space", "move and toggle in a list"],
        ["?",          "show this help (on an empty answer)"],
        ["Ctrl-C",     "abort without saving"]
      ].freeze

      # @param can_back [Boolean] whether there is a question to go back to;
      #   when false the back keys do nothing
      def initialize(can_back: true)
        @can_back = can_back
        @length   = 0
        @line     = nil
      end

      # The one-line reminder drawn above each collecting prompt.
      #
      # @param can_back [Boolean]
      # @return [String]
      def self.hint(can_back:)
        [("⌫ back" if can_back), "^S skip", "? keys", "^C abort"].compact.join(" · ")
      end

      # tty-reader calls this for every key, after any key-specific handler.
      #
      # @param event [TTY::Reader::KeyEvent]
      # @return [void]
      # @raise [Navigation] when the key navigates
      def keypress(event)
        name = event.key.name
        raise Navigation, :skip if name == :ctrl_s
        raise Navigation, :back if @can_back && (name == :ctrl_b || (BACKSPACE.include?(name) && @length.zero?))
        raise Navigation, :help if event.value == "?" && @length.zero?

        track(event)
      end

      private

      # Updates the typed-character count after an editing key.
      #
      # A line widget passes its whole line (prompt plus text) with each
      # event; list widgets pass an empty string, and the only text they hold
      # is the number typed into an enum_select.
      #
      # @param event [TTY::Reader::KeyEvent]
      # @return [void]
      def track(event)
        return reset if %i[return enter].include?(event.key.name)
        return track_keys(event) if event.line.to_s.empty?

        delta = @line ? event.line.length - @line.length : first_delta(event)
        @length = [@length + delta, 0].max
        @line = event.line
      end

      # The first event of a line has nothing to diff against; the line
      # started empty, so only a printable character changed it.
      def first_delta(event) = printable?(event.value) ? 1 : 0

      def track_keys(event)
        if BACKSPACE.include?(event.key.name) || event.key.name == :delete
          @length = [@length - 1, 0].max
        elsif event.key.name == :num
          @length += event.value.length
        end
      end

      # Enter submits; a widget that reads several lines (multiline text)
      # starts the next one empty.
      def reset
        @length = 0
        @line = nil
      end

      def printable?(value)
        value.to_s.length == 1 && value.match?(/[[:print:]]/)
      end
    end
  end
end
