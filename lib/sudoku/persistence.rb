# frozen_string_literal: true

require "fileutils"
require "json"
require "set"
require "glib2"
require_relative "preferences"

module Sudoku
  # Ported from upstream src/core/persistence.py.
  #
  # Every read and write of the two files the game keeps in the user's data
  # directory: board.json (the game in progress) and preferences.json. The
  # board file is the "continue game" save; deleting it is what makes the main
  # menu's Continue button disappear.
  module Persistence
    SAVE_BASENAME = "board.json"
    PREFERENCES_BASENAME = "preferences.json"
    DEFAULT_DIFFICULTY = 0.2
    UNKNOWN_VARIANT = "Unknown"

    class << self
      def data_dir
        File.join(GLib.user_data_dir, "sudokugame").tap do |dir|
          FileUtils.mkdir_p(dir)
        end
      end

      def save_path = File.join(data_dir, SAVE_BASENAME)

      def preferences_path = File.join(data_dir, PREFERENCES_BASENAME)

      def saved_game? = File.exist?(save_path)

      def clear_save
        if File.exist?(save_path)
          File.delete(save_path)
        end
      end

      # The variant of the saved game, so the window knows which controller to
      # build before loading it. nil means there is no save at all.
      def variant
        if File.exist?(save_path)
          read_json(save_path).fetch("variant", UNKNOWN_VARIANT)
        end
      end

      def read_preferences_file
        if File.exist?(preferences_path)
          read_json(preferences_path)
        else
          {}
        end
      end

      def write_preferences_file(data)
        File.write(preferences_path, JSON.generate(data))
      end

      def load_general_preferences
        preferences = PreferencesManager.get_preferences
        defaults = preferences.general_toggles.merge(preferences.general_counted)
        saved = read_preferences_file
        if saved.empty?
          defaults
        else
          general = saved.reject { |key, _| key == "variant_preferences" }
          PreferencesMigration.migrate_general(general, defaults)
        end
      end

      # variant_defaults is already hydrated by apply_variant_preferences
      # before the board is constructed, so this just hands back a copy.
      def load_variant_preferences(_variant)
        preferences = PreferencesManager.get_preferences
        if preferences
          preferences.variant_defaults.dup
        else
          {}
        end
      end

      # Loads the saved preferences for one variant into the live manager.
      def apply_variant_preferences(variant_name)
        preferences = PreferencesManager.get_preferences
        if preferences
          saved = read_preferences_file.fetch("variant_preferences", {})
          if saved.key?(variant_name)
            preferences.variant_defaults.update(saved[variant_name])
          end
        end
      end

      def save_preferences
        preferences = PreferencesManager.get_preferences
        if preferences
          read_preferences_file.tap do |data|
            data.update(preferences.general_toggles)
            data.update(preferences.general_counted)
            unless preferences.variant_defaults.empty?
              data["variant_preferences"] ||= {}
              data["variant_preferences"][preferences.variant_key] = preferences.variant_defaults
            end
            write_preferences_file(data)
          end
        end
      end

      def save_general_preferences(general_preferences = nil)
        read_preferences_file.tap do |data|
          data.update(general_preferences || current_general_preferences)
          write_preferences_file(data)
        end
      end

      # Builds a board of `board_class` from the save file, or nil when there
      # is nothing saved. Raises when a game is loaded with no preferences set,
      # which would leave the board without its variant options.
      def load_game(board_class, generator:, block_size:)
        if File.exist?(save_path)
          state = read_json(save_path)
          if PreferencesManager.get_preferences.nil?
            raise "Preferences are not initialized. [id=0]"
          end

          board_from_state(
            board_class,
            state,
            generator,
            block_size,
          )
        end
      end

      def save_game(board)
        File.write(save_path, JSON.generate(state_from_board(board)))
      end

      # One-time move of the preferences that older versions kept inside the
      # board file into preferences.json.
      def migrate_preferences_from_board
        preferences = PreferencesManager.get_preferences
        if File.exist?(save_path) && !File.exist?(preferences_path) && preferences
          state = read_json(save_path)
          if state.key?("general_preferences") || state.key?("variant_preferences")
            write_preferences_file(migrated_from_state(state, preferences))
            File.write(save_path, JSON.generate(state))
          end
        end
      end

      private

        def current_general_preferences
          preferences = PreferencesManager.get_preferences
          preferences.general_toggles.merge(preferences.general_counted)
        end

        def read_json(path)
          JSON.parse(File.read(path, encoding: "UTF-8"))
        end

        def board_from_state(board_class, state, generator, block_size)
          board_class.new(
            generator:        generator,
            puzzle:           state["puzzle"],
            solution:         state["solution"],
            difficulty:       state.fetch("difficulty", DEFAULT_DIFFICULTY),
            difficulty_label: state.fetch("difficulty_label", UNKNOWN_VARIANT),
            variant:          state.fetch("variant", UNKNOWN_VARIANT),
            block_size:       block_size,
          ).tap do |board|
            board.mistakes = state.fetch("mistakes", 0)
            restore_inputs(board, state["user_inputs"])
            restore_notes(board, state["notes"])
          end
        end

        def restore_inputs(board, saved_inputs)
          if saved_inputs
            saved_inputs.each_with_index do |row, r|
              row.each_with_index do |value, c|
                board.user_inputs[r][c] = value
              end
            end
          end
        end

        def restore_notes(board, saved_notes)
          if saved_notes
            saved_notes.each_with_index do |row, r|
              row.each_with_index do |notes, c|
                board.notes[r][c] = Set.new(notes.map(&:to_s))
              end
            end
          end
        end

        def state_from_board(board)
          {
            "difficulty"       => board.difficulty,
            "difficulty_label" => board.difficulty_label,
            "mistakes"         => board.mistakes,
            "variant"          => board.variant,
            "puzzle"           => board.puzzle,
            "solution"         => board.solution,
            "user_inputs"      => board.user_inputs,
            "notes"            => board.notes.map { |row| row.map(&:to_a) },
          }
        end

        # Pulls the legacy sections out of `state` — which the caller then
        # writes back without them — and returns the preferences file they
        # become.
        def migrated_from_state(state, preferences)
          {}.tap do |migrated|
            if state.key?("general_preferences")
              defaults = preferences.general_toggles.merge(preferences.general_counted)
              migrated.update(
                PreferencesMigration.migrate_general(state.delete("general_preferences"), defaults),
              )
            end
            if state.key?("variant_preferences")
              variant_name = state.fetch("variant", UNKNOWN_VARIANT)
              migrated["variant_preferences"] = {variant_name => state.delete("variant_preferences")}
            end
          end
        end
    end
  end
end
