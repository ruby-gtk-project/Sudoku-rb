# frozen_string_literal: true

require "json"
require_relative "log_utils"

module Sudoku
  # Raised when puzzle generation outruns its timeout, matching upstream's
  # TimeoutError from src/core/generator.py.
  class GenerationTimeout < StandardError; end

  # Raised when the generation worker fails, matching upstream's RuntimeError.
  class GenerationFailed < StandardError; end

  # Port-specific support for src/core/generator.py.
  #
  # Upstream delegates the actual puzzle construction to the `sudoku` PyPI
  # package (PuzzleGenerator.make_puzzle). There is no Ruby equivalent, so the
  # engine lives here: a bitmask solver over a list of "units" — the groups of
  # cells that must hold distinct values. Rows, columns and blocks are the
  # units every variant has; a variant adds its own (the two diagonals, for
  # Diagonal Sudoku) and the same solver then enforces them.
  class GridSolver
    def initialize(size:, block_size:, extra_units: [])
      @size = size
      @block_size = block_size
      @units = standard_units + extra_units
      @cell_units = cell_unit_index
      @full_mask = (1 << (size + 1)) - 2
      @values_for = mask_value_table
      @popcount = @values_for.map(&:length)
    end

    # Fills every empty cell of `grid` in place with a valid value, trying
    # values in random order so repeated calls give different grids. Answers
    # whether a filling was found.
    def fill_random(grid)
      fill(grid, unit_masks(grid), 0)
    end

    # Counts the grid's solutions, stopping as soon as `limit` of them have
    # been found — the uniqueness test only ever needs to know "one or more
    # than one".
    def count_solutions(grid, limit: 2)
      count(grid, unit_masks(grid), limit)
    end

    private

      def standard_units
        [].tap do |units|
          @size.times do |r|
            units << @size.times.map { |c| [r, c] }
          end
          @size.times do |c|
            units << @size.times.map { |r| [r, c] }
          end
          blocks_per_side = @size / @block_size
          blocks_per_side.times do |br|
            blocks_per_side.times do |bc|
              units << block_cells(br, bc)
            end
          end
        end
      end

      def block_cells(block_row, block_col)
        [].tap do |cells|
          @block_size.times do |r|
            @block_size.times do |c|
              cells << [block_row * @block_size + r, block_col * @block_size + c]
            end
          end
        end
      end

      # For every cell, the ids of the units it belongs to — the only thing the
      # hot path needs.
      def cell_unit_index
        Array.new(@size) { Array.new(@size) { [] } }.tap do |index|
          @units.each_with_index do |cells, unit_id|
            cells.each { |(r, c)| index[r][c] << unit_id }
          end
        end
      end

      # One bitmask per unit, with bit N set when value N is already placed in
      # it. Kept in step with the grid by #place and #unplace.
      def unit_masks(grid)
        Array.new(@units.length, 0).tap do |masks|
          @units.each_with_index do |cells, unit_id|
            cells.each do |(r, c)|
              value = grid[r][c]
              if value
                masks[unit_id] |= 1 << value
              end
            end
          end
        end
      end

      # Every candidate bitmask's values, worked out once at construction, so
      # the search never allocates a candidate list.
      def mask_value_table
        Array.new(1 << (@size + 1)) do |mask|
          (1..@size).select { |value| mask.anybits?(1 << value) }
        end
      end

      def candidate_mask(masks, row, col)
        used = 0
        @cell_units[row][col].each { |unit_id| used |= masks[unit_id] }
        @full_mask & ~used
      end

      def candidate_values(masks, row, col)
        @values_for[candidate_mask(masks, row, col)]
      end

      def place(grid, masks, row, col, value)
        grid[row][col] = value
        @cell_units[row][col].each { |unit_id| masks[unit_id] |= 1 << value }
      end

      def unplace(grid, masks, row, col, value)
        grid[row][col] = nil
        @cell_units[row][col].each { |unit_id| masks[unit_id] &= ~(1 << value) }
      end

      def fill(grid, masks, index)
        if index >= @size * @size
          true
        else
          row, col = index.divmod(@size)
          if grid[row][col]
            fill(grid, masks, index + 1)
          else
            fill_cell(
              grid,
              masks,
              row,
              col,
              index,
            )
          end
        end
      end

      def fill_cell(grid, masks, row, col, index)
        candidate_values(masks, row, col).shuffle.any? do |value|
          place(
            grid,
            masks,
            row,
            col,
            value,
          )
          filled = fill(grid, masks, index + 1)
          unless filled
            unplace(
              grid,
              masks,
              row,
              col,
              value,
            )
          end
          filled
        end
      end

      def count(grid, masks, limit)
        cell = scarcest_empty_cell(grid, masks)
        if cell.nil?
          1
        else
          count_branches(
            grid,
            masks,
            cell,
            limit,
          )
        end
      end

      def count_branches(grid, masks, cell, limit)
        row, col, free = cell
        total = 0
        @values_for[free].each do |value|
          place(
            grid,
            masks,
            row,
            col,
            value,
          )
          total += count(grid, masks, limit - total)
          unplace(
            grid,
            masks,
            row,
            col,
            value,
          )
          if total >= limit
            break
          end
        end
        total
      end

      # The empty cell with the fewest candidates, as [row, col, mask], or nil
      # when the grid is full. A cell with none makes the branch dead, and
      # picking it first is what prunes the search; a cell with one or none is
      # as good as the scan can do, so the scan stops there.
      def scarcest_empty_cell(grid, masks)
        fewest = nil
        fewest_count = @size + 1
        catch(:settled) do
          @size.times do |row|
            @size.times do |col|
              if grid[row][col].nil?
                free = candidate_mask(masks, row, col)
                available = @popcount[free]
                if available < fewest_count
                  fewest = [row, col, free]
                  fewest_count = available
                end
                if available <= 1
                  throw(:settled)
                end
              end
            end
          end
        end
        fewest
      end
  end

  # Ported from upstream src/core/generator.py (CoreSudokuGenerator).
  #
  # Generates in a forked worker with a timeout, as upstream does with
  # multiprocessing: the parent blocks on a pipe rather than on the puzzle
  # search, which keeps the loading screen's spinner turning. Where fork is
  # unavailable the work happens in-process instead.
  class CoreSudokuGenerator
    DEFAULT_TIMEOUT = 15
    DEFAULT_SIZE = 9
    DEFAULT_BLOCK_SIZE = 3

    # The share of cells dug out of the solution, from Easy (0.2) to Extreme
    # (0.9): 48% of the board at Easy up to 76% at Extreme. Uniqueness is
    # enforced per removal, so a dig that would make the puzzle ambiguous is
    # put back and the hole count lands at or below the target.
    MIN_HOLE_FRACTION = 0.4
    HOLE_FRACTION_RANGE = 0.4

    def generate(difficulty, timeout: DEFAULT_TIMEOUT)
      if Process.respond_to?(:fork)
        generate_in_worker(difficulty, timeout)
      else
        generate_impl(difficulty)
      end
    end

    # Variants override this. The default builds a puzzle with the variant's
    # own units, which is all Classic and Diagonal Sudoku need.
    def generate_impl(difficulty)
      build_puzzle(difficulty)
    end

    def size = DEFAULT_SIZE

    def block_size = DEFAULT_BLOCK_SIZE

    # The units beyond rows, columns and blocks that this variant constrains.
    def extra_units = []

    def solver
      @solver ||= GridSolver.new(size: size, block_size: block_size, extra_units: extra_units)
    end

    private

      def build_puzzle(difficulty)
        solution = complete_grid
        [punch_holes(solution, hole_count(difficulty)), solution]
      end

      def complete_grid
        Array.new(size) { Array.new(size) }.tap do |grid|
          unless solver.fill_random(grid)
            raise GenerationFailed, "Could not build a complete grid"
          end
        end
      end

      def hole_count(difficulty)
        share = MIN_HOLE_FRACTION + (HOLE_FRACTION_RANGE * difficulty.to_f.clamp(0.0, 1.0))
        (size * size * share).round
      end

      # Digs cells out of the solution in random order, keeping a removal only
      # while the puzzle still has exactly one solution.
      def punch_holes(solution, holes)
        solution.map(&:dup).tap do |puzzle|
          removed = 0
          shuffled_positions.each do |(row, col)|
            if removed >= holes
              break
            end

            if try_remove(puzzle, row, col)
              removed += 1
            end
          end
        end
      end

      def try_remove(puzzle, row, col)
        value = puzzle[row][col]
        puzzle[row][col] = nil
        unique = solver.count_solutions(puzzle, limit: 2) == 1
        unless unique
          puzzle[row][col] = value
        end
        unique
      end

      def shuffled_positions
        [].tap do |positions|
          size.times do |row|
            size.times { |col| positions << [row, col] }
          end
          positions.shuffle!
        end
      end

      # Upstream's _generate_worker, over a pipe instead of a queue.
      def generate_in_worker(difficulty, timeout)
        reader, writer = IO.pipe
        pid = fork do
          reader.close
          run_worker(writer, difficulty)
        end
        writer.close
        collect_worker_result(reader, pid, timeout)
      end

      def run_worker(writer, difficulty)
        payload = worker_payload(difficulty)
        writer.write(JSON.generate(payload))
        writer.close
        exit!(0)
      end

      def worker_payload(difficulty)
        {"puzzle" => nil, "solution" => nil}.tap do |payload|
          begin
            puzzle, solution = generate_impl(difficulty)
            payload["puzzle"] = puzzle
            payload["solution"] = solution
          rescue StandardError => error
            payload["error"] = error.message
          end
        end
      end

      def collect_worker_result(reader, pid, timeout)
        begin
          payload = read_payload(reader, pid, timeout)
        ensure
          reader.close
        end
        parse_payload(payload)
      end

      # Reads the worker's JSON until it closes the pipe, or gives up when the
      # timeout passes and takes the worker down with it.
      def read_payload(reader, pid, timeout)
        deadline = monotonic_now + timeout
        chunks = +""
        closed = false
        until closed
          remaining = deadline - monotonic_now
          unless remaining.positive?
            break
          end

          ready = IO.select(
            [reader],
            nil,
            nil,
            remaining,
          )
          if ready.nil?
            break
          end

          chunk = reader.read_nonblock(4096, exception: false)
          case chunk
          when nil
            closed = true
          when :wait_readable
            next
          else
            chunks << chunk
          end
        end
        reap_worker(pid, closed)
        chunks
      end

      def reap_worker(pid, closed)
        unless closed
          terminate_worker(pid)
          raise GenerationTimeout, "Puzzle generation timed out"
        end

        begin
          Process.wait(pid)
        rescue Errno::ECHILD
          nil
        end
      end

      def terminate_worker(pid)
        Process.kill("TERM", pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end

      def parse_payload(payload)
        begin
          data = JSON.parse(payload)
        rescue JSON::ParserError
          raise GenerationFailed, "Puzzle generation produced no result"
        end
        if data["error"]
          raise GenerationFailed, "Puzzle generation failed: #{data['error']}"
        end

        [data.fetch("puzzle"), data.fetch("solution")]
      end

      def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
