# frozen_string_literal: true

require "logger"
require "stringio"

module Sudoku
  # Ported from upstream src/log_utils.py (LogBufferHandler).
  #
  # The in-memory log sink. Upstream attaches a logging.Handler keeping every
  # formatted record in a StringIO so the about dialog can paste the session's
  # logs into its debug info; this is the same sink, written as a Logger device
  # so records still reach stderr on their way into the buffer.
  class LogBuffer
    def initialize
      @stream = StringIO.new
    end

    def write(message)
      @stream.write(message)
      $stderr.write(message)
      message.bytesize
    end

    def close = nil

    def logs = @stream.string
  end

  # Ported from upstream src/log_utils.py (setup_logging).
  #
  # Upstream also re-routes GLib's own diagnostics into Python logging with
  # GLib.log_set_writer_func. The Ruby bindings expose no writer func and
  # GLib's structured logging bypasses the per-domain handlers they do expose,
  # so GTK's own warnings stay on stderr and only the application's records
  # reach the buffer.
  module LogUtils
    class << self
      attr_reader :buffer

      def logger
        @logger ||= Logger.new($stderr, level: Logger::DEBUG)
      end

      def setup_logging
        LogBuffer.new.tap do |sink|
          @buffer = sink
          @logger = Logger.new(sink, level: Logger::DEBUG)
        end
      end

      def logs
        if @buffer
          @buffer.logs
        else
          ""
        end
      end
    end
  end
end
