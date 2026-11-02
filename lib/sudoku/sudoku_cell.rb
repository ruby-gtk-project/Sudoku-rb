# frozen_string_literal: true

require "set"
require "gtk4"

module Sudoku
  # Ported from upstream src/shared/utils.py.
  #
  # The two helpers every layer uses to put a temporary CSS class on a widget
  # and to take feedback classes back off again.
  module CellFeedback
    DEFAULT_DELAY = 4000

    # Adds `css_class` to the widget and schedules its removal, cancelling the
    # timeout the caller passed back in. Answers the new timeout's source id.
    def self.schedule_clear(widget, css_class, delay_ms, previous_source_id = nil)
      if previous_source_id
        GLib::Source.remove(previous_source_id)
      end

      widget.add_css_class(css_class)
      GLib::Timeout.add(delay_ms) do
        widget.remove_css_class(css_class)
        false
      end
    end

    # Removes feedback classes and the tooltip that went with them.
    def self.clear(widget, *css_classes)
      css_classes.each { |css_class| widget.remove_css_class(css_class) }
      widget.tooltip_text = ""
    end
  end

  # Ported from upstream src/shared/sudoku_cell.py
  # (SudokuCellNotesManagement).
  #
  # The pencil notes of one cell: a homogeneous grid of small labels laid out
  # like a telephone keypad, overlaid on the cell's value label.
  class SudokuCellNotes
    COMPACT_LABEL_SIZE = 8
    LABEL_SIZE = 12

    attr_reader :note_labels

    def initialize(cell)
      @cell = cell
      @note_labels = {}
    end

    def notes_grid
      @notes_grid ||= Gtk::Grid.new.tap do |grid|
        grid.row_spacing = 0
        grid.column_spacing = 0
        grid.column_homogeneous = true
        grid.row_homogeneous = true
        grid.halign = :fill
        grid.valign = :fill
      end
    end

    # Rebuilds the note labels. Notes are hidden while the cell holds a value,
    # which is what upstream's empty-main-text check amounts to.
    def update(notes)
      clear_labels
      unless notes.nil? || notes.to_a.empty? || @cell.value
        notes.to_a.sort_by(&:to_i).each { |note| attach_note(note) }
        notes_grid.show
      end
    end

    private

      def clear_labels
        while (child = notes_grid.first_child)
          notes_grid.remove(child)
        end
        @note_labels.clear
      end

      def attach_note(note)
        note_label(note).tap do |label|
          @note_labels[note] = label
          index = note.to_i - 1
          notes_grid.attach(
            label,
            index % @cell.block_size,
            index / @cell.block_size,
            1,
            1,
          )
        end
      end

      def note_label(note)
        Gtk::Label.new(note.to_s).tap do |label|
          label.add_css_class("note-cell-label")
          if @cell.compact_mode?
            size = COMPACT_LABEL_SIZE
          else
            size = LABEL_SIZE
          end
          label.set_size_request(size, size)
          label.halign = :fill
          label.valign = :fill
        end
      end
  end

  # Ported from upstream src/shared/sudoku_cell.py (SudokuCell, and the
  # SudokuCellUIManagement that only exists there to hold its widgets).
  #
  # One cell of the grid: a button whose child is the value label with the
  # notes grid overlaid on it. The cell owns its value, its pencil notes, its
  # editability and the timeout that clears visual feedback.
  class SudokuCell < Gtk::Button
    type_register

    COMPACT_SIZE = 10
    SIZE = 40

    attr_accessor :row, :col
    attr_reader :value, :correct_value, :block_size, :notes_manager

    def initialize(value:, correct_value:, editable:, block_size: 3)
      super()
      @value = value
      @correct_value = correct_value
      @editable = editable
      @block_size = block_size
      @compact_mode = false
      @feedback_source_id = nil
      @notes_manager = SudokuCellNotes.new(self)
      build
    end

    def build
      tap do |cell|
        cell.focusable = true
        cell.add_css_class("sudoku-cell-button")
        if @value.nil?
          cell.add_css_class("entry-cell")
        else
          cell.add_css_class("clue-cell")
        end
        cell.child = overlay

        overlay.tap do |stack|
          stack.child = main_label
          stack.add_overlay(notes_manager.notes_grid)
        end

        cell.signal_connect("clicked") { on_clicked }
      end
      set_value(@value)
    end

    def editable=(editable)
      @editable = editable
    end

    def editable? = @editable

    def compact_mode? = @compact_mode

    def set_value(value)
      @value = value
      if value.nil?
        main_label.text = ""
      else
        main_label.text = value.to_s
      end
      notes_manager.notes_grid.visible = value.nil?
    end

    def update_notes(notes)
      notes_manager.update(notes)
    end

    # Compact mode shrinks the cell and redraws the notes at the smaller font;
    # a redundant switch is skipped so the notes are not rebuilt for nothing.
    def set_compact(compact)
      unless @compact_mode == compact
        @compact_mode = compact
        if compact
          size = COMPACT_SIZE
        else
          size = SIZE
        end
        set_size_request(size, size)
        update_notes(Set.new(notes_manager.note_labels.keys))
      end
    end

    def highlight(class_name)
      add_css_class(class_name)
    end

    def remove_highlight(class_name)
      remove_css_class(class_name)
    end

    def clear
      set_value(nil)
      update_notes(Set.new)
      remove_highlight("wrong")
    end

    def start_feedback_timeout(delay: CellFeedback::DEFAULT_DELAY, &callback)
      clear_feedback_timeout
      @feedback_source_id = GLib::Timeout.add(delay) do
        @feedback_source_id = nil
        callback.call
      end
    end

    def clear_feedback_timeout
      if @feedback_source_id
        begin
          GLib::Source.remove(@feedback_source_id)
        rescue StandardError
          nil
        end
        @feedback_source_id = nil
      end
    end

    def main_label
      @main_label ||= Gtk::Label.new.tap do |label|
        label.xalign = 0.5
        label.yalign = 0.5
        label.halign = :center
        label.valign = :center
        label.hexpand = true
        label.vexpand = true
      end
    end

    def overlay
      @overlay ||= Gtk::Overlay.new.tap do |stack|
        stack.halign = :fill
        stack.valign = :fill
      end
    end

    private

      # A clue cell must not react to clicks; upstream stops the "clicked"
      # emission for it rather than making the button insensitive, which would
      # grey the clue out.
      def on_clicked
        unless @editable
          signal_emit_stop("clicked")
        end
      end
  end
end
