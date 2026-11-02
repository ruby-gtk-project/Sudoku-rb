# frozen_string_literal: true

require "gtk4"

module Sudoku
  # Ported from upstream src/shared/grid_manager.py.
  #
  # Builds the grid the game is played on: one parent grid of nine block
  # grids, each holding nine cells, wrapped in a square aspect frame. The cells
  # themselves belong to the board; this adds them to the layout and gives each
  # one its click gesture and key controller.
  class GridManager
    PARENT_SPACING = 10
    BLOCK_SPACING = 4
    MODE_CLASSES = {
      "compact-mode" => "compact",
      "small-mode"   => "small",
      "large"        => "large",
    }.freeze

    attr_reader :board_size, :block_size, :parent_grid, :blocks, :cells, :board_frame

    def initialize
      @board_size = 0
      @block_size = 0
      @blocks = []
      @cells = []
      @parent_grid = nil
      @board_frame = nil
    end

    def setup(window, board, input_handler, popover_manager)
      @window = window
      @board = board
      @input_handler = input_handler
      @popover_manager = popover_manager
      @board_size = board.size
      @block_size = board.block_size
    end

    def build_grid
      clear_previous_grid
      @parent_grid = create_parent_grid
      @blocks = create_blocks
      @cells = create_cells
      @board_frame = wrap_in_aspect_frame(@parent_grid)
      @window.grid_container.append(@board_frame)
      @board_frame.show
      reapply_compact_mode
      @window.grid_container.queue_allocate
    end

    def clear_previous_grid
      if @popover_manager
        @popover_manager.invalidate
      end

      @cells.each { |row| row.each { |cell| cell&.clear_feedback_timeout } }
      while (child = @window.grid_container.first_child)
        @window.grid_container.remove(child)
      end
    end

    private

      def create_parent_grid
        Gtk::Grid.new.tap do |grid|
          grid.row_spacing = PARENT_SPACING
          grid.column_spacing = PARENT_SPACING
          grid.column_homogeneous = true
          grid.row_homogeneous = true
          grid.name = "sudoku-parent-grid"
        end
      end

      def create_blocks
        blocks_per_side = @board_size / @block_size
        Array.new(blocks_per_side) do |block_row|
          Array.new(blocks_per_side) do |block_col|
            block_grid.tap { |block| @parent_grid.attach(
              block,
              block_col,
              block_row,
              1,
              1,
            ) }
          end
        end
      end

      def block_grid
        Gtk::Grid.new.tap do |block|
          block.row_spacing = BLOCK_SPACING
          block.column_spacing = BLOCK_SPACING
          block.column_homogeneous = true
          block.row_homogeneous = true
          block.add_css_class("sudoku-block")
        end
      end

      def create_cells
        Array.new(@board_size) do |row|
          Array.new(@board_size) do |col|
            @board.sudoku_cells[row][col].tap do |cell|
              cell.row = row
              cell.col = col
              cell.add_controller(@input_handler.make_cell_gesture(row, col))
              cell.add_controller(@input_handler.make_cell_key_controller(row, col))
              attach_cell(cell, row, col)
            end
          end
        end
      end

      def attach_cell(cell, row, col)
        block = @blocks[row / @block_size][col / @block_size]
        block.attach(
          cell,
          col % @block_size,
          row % @block_size,
          1,
          1,
        )
      end

      def wrap_in_aspect_frame(child)
        Gtk::AspectFrame.new(
          0.5,
          0.5,
          1.0,
          false,
        ).tap do |frame|
          frame.hexpand = true
          frame.vexpand = true
          frame.halign = :fill
          frame.valign = :fill
          frame.child = child
        end
      end

      # A grid built while the window is already narrow has to pick up the
      # breakpoint's mode, which was applied before the grid existed.
      def reapply_compact_mode
        breakpoint_bin = @window.bp_bin
        if breakpoint_bin
          MODE_CLASSES.each do |css_class, mode|
            if breakpoint_bin.has_css_class?(css_class)
              @window.apply_mode(true, mode)
              break
            end
          end
        end
      end
  end
end
