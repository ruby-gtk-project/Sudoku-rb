# frozen_string_literal: true

require "tmpdir"

# Ported from upstream tests/test_board_serialization.py. Upstream patches
# `_get_save_path`/`_get_preferences_path`; the port's `Persistence.save_path`
# and `.preferences_path` are derived from `GLib.user_data_dir`, so that is
# what gets stubbed here to the same effect: a save file under a tmp dir.

SERIALIZATION_PUZZLE = [
  [1, nil, 3, nil, 5, nil, 7, nil, 9],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
  [nil, nil, nil, nil, nil, nil, nil, nil, nil],
].freeze

SERIALIZATION_SOLUTION = [
  [1, 2, 3, 4, 5, 6, 7, 8, 9],
  [4, 5, 6, 7, 8, 9, 1, 2, 3],
  [7, 8, 9, 1, 2, 3, 4, 5, 6],
  [2, 3, 4, 5, 6, 7, 8, 9, 1],
  [5, 6, 7, 8, 9, 1, 2, 3, 4],
  [8, 9, 1, 2, 3, 4, 5, 6, 7],
  [3, 4, 5, 6, 7, 8, 9, 1, 2],
  [6, 7, 8, 9, 1, 2, 3, 4, 5],
  [9, 1, 2, 3, 4, 5, 6, 7, 8],
].freeze

RSpec.describe "board serialization" do
  before do
    @tmpdir = Dir.mktmpdir
    allow(GLib).to receive(:user_data_dir).and_return(@tmpdir)
  end

  after do
    FileUtils.remove_entry(@tmpdir)
  end

  let(:save_path) { Sudoku::Persistence.save_path }
  let(:prefs_path) { Sudoku::Persistence.preferences_path }

  let(:prefs) do
    Sudoku::ClassicSudokuPreferences.new.tap { |p| Sudoku::PreferencesManager.set_preferences(p) }
  end
  let(:diagonal_prefs) do
    Sudoku::DiagonalSudokuPreferences.new.tap { |p| Sudoku::PreferencesManager.set_preferences(p) }
  end

  let(:classic_board) do
    prefs
    make_board_state(Sudoku::ClassicSudokuBoard, puzzle: SERIALIZATION_PUZZLE, solution: SERIALIZATION_SOLUTION).tap do |board|
      board.set_input(1, 0, 4)
      board.toggle_note(1, 1, "5")
      board.toggle_note(1, 1, "8")
      board.mistakes = 2
    end
  end

  let(:diagonal_board) do
    make_board_state(Sudoku::DiagonalSudokuBoard, puzzle: SERIALIZATION_PUZZLE, solution: SERIALIZATION_SOLUTION).tap do |board|
      board.set_input(1, 0, 4)
      board.toggle_note(2, 2, "9")
      board.mistakes = 1
      # Upstream's fixture overrides these two fields directly after
      # construction; the port's board exposes them as read-only
      # attr_readers, so the override goes through the ivars instead.
      board.instance_variable_set(:@variant, "diagonal")
      board.instance_variable_set(:@variant_preferences, diagonal_prefs.variant_defaults.dup)
    end
  end

  # Ported from TestClassicRoundtrip.
  describe "classic roundtrip" do
    it "test_preserves_board_state" do
      Sudoku::Persistence.save_game(classic_board)
      loaded = Sudoku::Persistence.load_game(Sudoku::ClassicSudokuBoard, generator: nil, block_size: 3)

      expect(loaded).not_to be_nil
      expect(loaded.puzzle).to eq(classic_board.puzzle)
      expect(loaded.solution).to eq(classic_board.solution)
      expect(loaded.user_inputs).to eq(classic_board.user_inputs)
      expect(loaded.mistakes).to eq(classic_board.mistakes)
      expect(loaded.variant).to eq("classic")
    end

    it "test_notes_roundtrip" do
      Sudoku::Persistence.save_game(classic_board)
      loaded = Sudoku::Persistence.load_game(Sudoku::ClassicSudokuBoard, generator: nil, block_size: 3)

      expect(loaded.notes[1][1]).to eq(Set.new(%w[5 8]))
    end
  end

  # Ported from TestDiagonalRoundtrip.
  describe "diagonal roundtrip" do
    it "test_preserves_board_state" do
      Sudoku::Persistence.save_game(diagonal_board)
      Sudoku::Persistence.save_preferences
      loaded = Sudoku::Persistence.load_game(Sudoku::DiagonalSudokuBoard, generator: nil, block_size: 3)

      expect(loaded).not_to be_nil
      expect(loaded.puzzle).to eq(diagonal_board.puzzle)
      expect(loaded.variant).to eq("diagonal")
    end

    it "test_notes_roundtrip" do
      Sudoku::Persistence.save_game(diagonal_board)
      Sudoku::Persistence.save_preferences
      loaded = Sudoku::Persistence.load_game(Sudoku::DiagonalSudokuBoard, generator: nil, block_size: 3)

      expect(loaded.notes[2][2]).to eq(Set.new(%w[9]))
    end

    it "test_variant_preferences_roundtrip" do
      Sudoku::Persistence.save_game(diagonal_board)
      Sudoku::Persistence.save_preferences
      loaded = Sudoku::Persistence.load_game(Sudoku::DiagonalSudokuBoard, generator: nil, block_size: 3)

      expect(loaded).not_to be_nil
      expect(loaded.variant_preferences["highlight_diagonals"]).to be(true)
    end
  end

  # Ported from TestSerializationFormat.
  describe "serialization format" do
    it "test_notes_serialized_as_lists" do
      Sudoku::Persistence.save_game(classic_board)
      raw = JSON.parse(File.read(save_path))
      notes_row = raw["notes"][1]
      expect(notes_row[1]).to be_a(Array)
      expect(notes_row[1].sort).to eq(%w[5 8])
    end

    it "test_load_returns_none_for_missing_file" do
      result = Sudoku::Persistence.load_game(Sudoku::ClassicSudokuBoard, generator: nil, block_size: 3)
      expect(result).to be_nil
    end

    it "test_load_defaults_missing_optional_fields" do
      prefs
      minimal_state = {
        "puzzle"      => SERIALIZATION_PUZZLE,
        "solution"    => SERIALIZATION_SOLUTION,
        "user_inputs" => Array.new(9) { Array.new(9) },
        "notes"       => Array.new(9) { Array.new(9) { [] } },
      }
      File.write(save_path, JSON.generate(minimal_state))

      loaded = Sudoku::Persistence.load_game(Sudoku::ClassicSudokuBoard, generator: nil, block_size: 3)
      expect(loaded).not_to be_nil
      expect(loaded.difficulty).to eq(0.2)
      expect(loaded.difficulty_label).to eq("Unknown")
      expect(loaded.variant).to eq("Unknown")
      expect(loaded.mistakes).to eq(0)
    end

    it "test_board_json_excludes_preferences" do
      Sudoku::Persistence.save_game(classic_board)
      raw = JSON.parse(File.read(save_path))
      expect(raw).not_to have_key("general_preferences")
      expect(raw).not_to have_key("variant_preferences")
    end
  end

  # Ported from TestClearSave.
  describe "clear save" do
    it "test_clear_save_removes_file" do
      Sudoku::Persistence.save_game(classic_board)
      expect(File.exist?(save_path)).to be(true)
      Sudoku::Persistence.clear_save
      expect(File.exist?(save_path)).to be(false)
    end

    it "test_clear_save_noop_when_no_file" do
      expect(File.exist?(save_path)).to be(false)
      expect { Sudoku::Persistence.clear_save }.not_to raise_error
    end

    it "test_has_saved_game_true_after_save" do
      Sudoku::Persistence.save_game(classic_board)
      expect(Sudoku::Persistence.saved_game?).to be(true)
    end

    it "test_has_saved_game_false_after_clear" do
      Sudoku::Persistence.save_game(classic_board)
      Sudoku::Persistence.clear_save
      expect(Sudoku::Persistence.saved_game?).to be(false)
    end

    it "test_has_saved_game_false_when_no_file" do
      expect(Sudoku::Persistence.saved_game?).to be(false)
    end

    it "test_clear_save_does_not_remove_preferences" do
      prefs
      Sudoku::Persistence.save_game(classic_board)
      Sudoku::Persistence.save_preferences
      Sudoku::Persistence.clear_save
      expect(File.exist?(save_path)).to be(false)
      expect(File.exist?(prefs_path)).to be(true)
    end
  end

  # Ported from TestPreferencesFile.
  describe "preferences file" do
    it "test_save_and_load_general_roundtrip" do
      prefs
      Sudoku::Persistence.save_preferences
      loaded = Sudoku::Persistence.load_general_preferences
      expect(loaded).to eq(prefs.general_toggles.merge(prefs.general_counted))
    end

    it "test_load_general_returns_defaults_when_no_file" do
      prefs
      loaded = Sudoku::Persistence.load_general_preferences
      expect(loaded).to eq(prefs.general_toggles.merge(prefs.general_counted))
    end

    it "test_save_general_overwrites_existing" do
      prefs
      Sudoku::Persistence.save_preferences
      updated = prefs.general_toggles.merge(prefs.general_counted)
      updated["casual_mode"] = {"value" => false, "tooltip" => "test"}
      Sudoku::Persistence.save_general_preferences(updated)
      loaded = Sudoku::Persistence.load_general_preferences
      expect(loaded["casual_mode"]["value"]).to be(false)
    end

    it "test_save_preferences_from_manager" do
      prefs.general_toggles["casual_mode"]["value"] = false
      Sudoku::Persistence.save_preferences
      raw = JSON.parse(File.read(prefs_path))
      expect(raw["casual_mode"]["value"]).to be(false)
    end

    it "test_save_preferences_writes_variant_by_name" do
      diagonal_prefs
      Sudoku::Persistence.save_preferences
      loaded = Sudoku::Persistence.load_variant_preferences("diagonal")
      expect(loaded["highlight_diagonals"]).to be(true)
    end

    it "test_load_variant_returns_defaults_for_unknown" do
      prefs
      loaded = Sudoku::Persistence.load_variant_preferences("nonexistent")
      expect(loaded).to eq(prefs.variant_defaults)
    end

    it "test_load_variant_returns_saved_value" do
      prefs
      Sudoku::Persistence.save_preferences
      loaded = Sudoku::Persistence.load_variant_preferences("classic")
      expect(loaded).to eq(prefs.variant_defaults)
    end

    it "test_general_preferences_survive_game_clear" do
      prefs
      classic_board
      Sudoku::Persistence.save_preferences
      Sudoku::Persistence.clear_save
      loaded = Sudoku::Persistence.load_general_preferences
      expect(loaded).to eq(prefs.general_toggles.merge(prefs.general_counted))
    end
  end

  # Ported from TestMigration.
  describe "migration" do
    it "test_migrates_both_general_and_variant" do
      diagonal_prefs
      old_state = {
        "puzzle"              => SERIALIZATION_PUZZLE,
        "solution"            => SERIALIZATION_SOLUTION,
        "variant"             => "diagonal",
        "general_preferences" => {"casual_mode" => {"value" => false, "tooltip" => "test"}},
        "variant_preferences" => {"highlight_diagonals" => true},
      }
      File.write(save_path, JSON.generate(old_state))

      Sudoku::Persistence.migrate_preferences_from_board

      expect(File.exist?(prefs_path)).to be(true)
      prefs_data = JSON.parse(File.read(prefs_path))
      expect(prefs_data["casual_mode"]["value"]).to be(false)
      expect(prefs_data["variant_preferences"]["diagonal"]).to eq({"highlight_diagonals" => true})

      board_data = JSON.parse(File.read(save_path))
      expect(board_data).not_to have_key("general_preferences")
      expect(board_data).not_to have_key("variant_preferences")
    end

    it "test_migrates_general_only" do
      prefs
      old_state = {
        "puzzle"              => SERIALIZATION_PUZZLE,
        "solution"            => SERIALIZATION_SOLUTION,
        "variant"             => "classic",
        "general_preferences" => {"casual_mode" => {"value" => false, "tooltip" => "test"}},
      }
      File.write(save_path, JSON.generate(old_state))

      Sudoku::Persistence.migrate_preferences_from_board

      prefs_data = JSON.parse(File.read(prefs_path))
      expect(prefs_data["casual_mode"]["value"]).to be(false)
      expect(prefs_data).not_to have_key("variant_preferences")
    end

    it "test_migrates_variant_only" do
      prefs
      old_state = {
        "puzzle"              => SERIALIZATION_PUZZLE,
        "solution"            => SERIALIZATION_SOLUTION,
        "variant"             => "diagonal",
        "variant_preferences" => {"highlight_diagonals" => true},
      }
      File.write(save_path, JSON.generate(old_state))

      Sudoku::Persistence.migrate_preferences_from_board

      prefs_data = JSON.parse(File.read(prefs_path))
      expect(prefs_data["variant_preferences"]["diagonal"]).to eq({"highlight_diagonals" => true})
      expect(prefs_data).not_to have_key("casual_mode")
    end

    it "test_migration_noop_when_prefs_file_exists" do
      prefs
      old_state = {
        "puzzle"              => SERIALIZATION_PUZZLE,
        "solution"            => SERIALIZATION_SOLUTION,
        "general_preferences" => {"casual_mode" => {"value" => true, "tooltip" => ""}},
      }
      File.write(save_path, JSON.generate(old_state))
      File.write(prefs_path, JSON.generate({"casual_mode" => {"value" => false, "tooltip" => "existing"}}))

      Sudoku::Persistence.migrate_preferences_from_board

      prefs_data = JSON.parse(File.read(prefs_path))
      expect(prefs_data["casual_mode"]["value"]).to be(false)
    end

    it "test_migration_noop_when_no_board_file" do
      prefs
      Sudoku::Persistence.migrate_preferences_from_board
      expect(File.exist?(prefs_path)).to be(false)
    end

    it "test_migration_noop_when_no_preferences_in_board" do
      prefs
      state = {"puzzle" => SERIALIZATION_PUZZLE, "solution" => SERIALIZATION_SOLUTION, "variant" => "classic"}
      File.write(save_path, JSON.generate(state))

      Sudoku::Persistence.migrate_preferences_from_board
      expect(File.exist?(prefs_path)).to be(false)
    end

    it "test_migration_old_bool_format" do
      prefs
      old_state = {
        "puzzle"              => SERIALIZATION_PUZZLE,
        "solution"            => SERIALIZATION_SOLUTION,
        "general_preferences" => {"casual_mode" => true, "auto_remove_notes" => false},
      }
      File.write(save_path, JSON.generate(old_state))

      Sudoku::Persistence.migrate_preferences_from_board

      prefs_data = JSON.parse(File.read(prefs_path))
      expect(prefs_data["casual_mode"]).to eq(
        {"value" => true, "tooltip" => prefs.general_toggles["casual_mode"]["tooltip"]},
      )
      expect(prefs_data["auto_remove_notes"]["value"]).to be(false)
    end
  end
end
