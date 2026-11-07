# frozen_string_literal: true

# Ported from upstream tests/test_preferences.py.

RSpec.describe "preferences" do
  # Ported from TestCoreSudokuPreferences.
  describe Sudoku::CoreSudokuPreferences do
    let(:prefs) { Sudoku::ClassicSudokuPreferences.new }

    it "test_general_returns_value_for_known_key" do
      expect(prefs.general("highlight_row")).to be(true)
    end

    it "test_general_returns_default_for_unknown_key" do
      expect(prefs.general("nonexistent_key")).to be(false)
    end

    it "test_general_returns_custom_default_for_unknown_key" do
      expect(prefs.general("nonexistent_key", default: 42)).to eq(42)
    end

    it "test_variant_returns_value_for_known_key" do
      expect(prefs.variant("highlight_block")).to be(true)
    end

    it "test_variant_returns_default_for_unknown_key" do
      expect(prefs.variant("nonexistent_key")).to be(false)
    end

    it "test_preferences_instances_are_independent" do
      a = Sudoku::ClassicSudokuPreferences.new
      b = Sudoku::ClassicSudokuPreferences.new
      a.variant_defaults["custom"] = true
      expect(b.variant_defaults).not_to have_key("custom")
    end
  end

  # Ported from TestGeneralCounted.
  describe "general_counted_entry" do
    let(:prefs) { Sudoku::ClassicSudokuPreferences.new }

    it "test_general_counted_entry_returns_dict" do
      entry = prefs.general_counted_entry("mistake_limit")
      expect(entry).to be_a(Hash)
      expect(entry).to have_key("enabled")
      expect(entry).to have_key("count")
    end

    it "test_general_counted_entry_returns_default_for_unknown" do
      expect(prefs.general_counted_entry("nonexistent")).to be_nil
    end

    it "test_general_counted_entry_returns_custom_default" do
      expect(prefs.general_counted_entry("nonexistent", {})).to eq({})
    end

    it "test_general_does_not_return_counted_entry" do
      expect(prefs.general("mistake_limit")).to be(false)
    end
  end

  # Ported from TestDiagonalPreferences.
  describe Sudoku::DiagonalSudokuPreferences do
    let(:prefs) { Sudoku::DiagonalSudokuPreferences.new }

    it "test_highlight_diagonals" do
      expect(prefs.variant("highlight_diagonals")).to be(true)
      expect(prefs.variant("highlight_block")).to be(true)
    end

    it "test_name" do
      expect(prefs.name).to eq("Diagonal Sudoku")
    end

    it "test_inherits_general_toggles" do
      expect(prefs.general("highlight_row")).to be(true)
      expect(prefs.general("highlight_column")).to be(true)
    end

    it "test_instances_are_independent" do
      a = Sudoku::DiagonalSudokuPreferences.new
      b = Sudoku::DiagonalSudokuPreferences.new
      a.variant_defaults["custom"] = true
      expect(b.variant_defaults).not_to have_key("custom")
    end

    it "test_vs_classic_variant_defaults" do
      classic = Sudoku::ClassicSudokuPreferences.new
      diagonal = Sudoku::DiagonalSudokuPreferences.new
      expect(classic.variant("highlight_diagonals")).to be(false)
      expect(diagonal.variant("highlight_diagonals")).to be(true)
    end
  end

  # Ported from TestMigrateGeneralPreferences. Upstream's module-level
  # `_migrate_general_preferences` is the port's `PreferencesMigration.migrate_general`.
  describe Sudoku::PreferencesMigration do
    it "test_new_format_dict_passthrough" do
      saved = {"highlight_row" => {"value" => true, "tooltip" => "test"}}
      result = described_class.migrate_general(saved, {})
      expect(result["highlight_row"]).to eq({"value" => true, "tooltip" => "test"})
    end

    it "test_old_format_list_converted" do
      saved = {"highlight_row" => ["Toggle row", true]}
      result = described_class.migrate_general(saved, {})
      expect(result["highlight_row"]).to eq({"value" => true, "tooltip" => "Toggle row"})
    end

    it "test_old_format_bool_converted" do
      saved = {"highlight_row" => true}
      defaults = {"highlight_row" => {"value" => false, "tooltip" => "Row tooltip"}}
      result = described_class.migrate_general(saved, defaults)
      expect(result["highlight_row"]).to eq({"value" => true, "tooltip" => "Row tooltip"})
    end

    it "test_unknown_format_falls_back_to_default" do
      saved = {"weird_key" => [1, 2, 3]}
      defaults = {"weird_key" => {"value" => false, "tooltip" => ""}}
      result = described_class.migrate_general(saved, defaults)
      expect(result["weird_key"]).to eq({"value" => false, "tooltip" => ""})
    end

    it "test_counted_toggle_dict_passthrough" do
      saved = {"mistake_limit" => {"enabled" => true, "count" => 5}}
      result = described_class.migrate_general(saved, {})
      expect(result["mistake_limit"]).to eq({"enabled" => true, "count" => 5})
    end

    it "test_empty_saved_returns_empty" do
      expect(described_class.migrate_general({}, {})).to eq({})
    end
  end

  # Ported from TestPreferencesManager.
  describe Sudoku::PreferencesManager do
    it "test_set_and_get" do
      prefs = Sudoku::ClassicSudokuPreferences.new
      described_class.set_preferences(prefs)
      expect(described_class.get_preferences).to be(prefs)
    end

    it "test_get_returns_none_initially" do
      described_class.set_preferences(nil)
      expect(described_class.get_preferences).to be_nil
    end

    it "test_set_replaces_previous" do
      a = Sudoku::ClassicSudokuPreferences.new
      b = Sudoku::DiagonalSudokuPreferences.new
      described_class.set_preferences(a)
      described_class.set_preferences(b)
      expect(described_class.get_preferences).to be(b)
    end
  end
end
