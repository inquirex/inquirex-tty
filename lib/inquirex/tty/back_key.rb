# frozen_string_literal: true

module Inquirex
  module TTY
    # The key that takes a TTY run back to the previous question.
    #
    # Ctrl-B, because it arrives: tty-reader maps byte 0x02 to +:ctrl_b+ in
    # every terminal, and tty-prompt binds nothing to it. Cmd-Backspace, the
    # first candidate, reaches a program only where the user has mapped it by
    # hand (iTerm2 sends nothing by default), so a run could never rely on it.
    module BackKey
      # @return [Symbol] the tty-reader key name
      NAME = :ctrl_b

      # @return [Symbol] the event tty-reader publishes when the key is pressed
      EVENT = :"key#{NAME}"

      # @return [String] how the tip line names the key
      LABEL = "Ctrl-B"

      # Raised from inside a tty-prompt read loop when the back key is pressed,
      # so whichever widget is open (ask, select, multi_select, yes?) unwinds
      # without returning an answer. tty-prompt offers no hook that aborts a
      # question, and a subclass per widget would mean overriding the read
      # loop of each one; one exception covers them all.
      class Pressed < StandardError
        def initialize(msg = "#{LABEL} pressed") = super
      end
    end
  end
end
