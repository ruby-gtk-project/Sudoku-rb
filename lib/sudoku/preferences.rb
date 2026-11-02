# frozen_string_literal: true

module Sudoku
  # Ported from upstream src/core/preferences.py (CoreSudokuPreferences).
  #
  # The preference schema and the live values in one object: the toggles every
  # variant shares, the counted "mistake limit" entry, and the variant's own
  # defaults. Keys stay strings because these dictionaries are written to and
  # read back from JSON verbatim.
  #
  # Upstream copies the class-level dictionaries shallowly, which leaves the
  # nested entry hashes shared with the class defaults; the copies here are
  # deep, so a game's edits cannot leak into the next game's defaults.
  class CoreSudokuPreferences
    GENERAL_TOGGLES = {
      "casual_mode"                      => {
        "value"   => true,
        "tooltip" => "Highlight when input does not match the correct solution",
      },
      "prevent_conflicting_pencil_notes" => {
        "value"   => false,
        "tooltip" => "",
      },
      "highlight_row"                    => {
        "value"   => true,
        "tooltip" => "",
      },
      "highlight_column"                 => {
        "value"   => true,
        "tooltip" => "",
      },
      "auto_remove_notes"                => {
        "value"   => false,
        "tooltip" => "Automatically remove pencil notes after a correct entry",
      },
      "show_remaining_valid_inputs"      => {
        "value"   => false,
        "tooltip" => "View the possible places left for each number",
      },
      "show_popover"                     => {
        "value"   => true,
        "tooltip" => "Show popover when clicking on a cell",
      },
    }.freeze

    GENERAL_COUNTED = {
      "mistake_limit" => {
        "enabled" => false,
        "count"   => 3,
        "tooltip" => "End the game or warn after a set number of mistakes",
      },
    }.freeze

    VARIANT_DEFAULTS = {}.freeze

    attr_accessor :name, :variant_key, :general_toggles, :general_counted, :variant_defaults

    def initialize
      @general_toggles = self.class.deep_dup(self.class::GENERAL_TOGGLES)
      @general_counted = self.class.deep_dup(self.class::GENERAL_COUNTED)
      @variant_defaults = self.class.deep_dup(self.class::VARIANT_DEFAULTS)
      @name = ""
      @variant_key = ""
    end

    def general(key, default: false)
      entry = @general_toggles[key]
      if entry.nil?
        default
      else
        entry.fetch("value", default)
      end
    end

    def general_counted_entry(key, default = nil)
      @general_counted.fetch(key, default)
    end

    def variant(key, default: false)
      @variant_defaults.fetch(key, default)
    end

    def self.deep_dup(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, nested), copy| copy[key] = deep_dup(nested) }
      when Array
        value.map { |nested| deep_dup(nested) }
      else
        value
      end
    end
  end

  # Ported from upstream src/core/preferences.py (_migrate_general_preferences).
  #
  # Older saves stored a general preference as a bare boolean or as a
  # [tooltip, value] pair; both are lifted to the current
  # {"value" =>, "tooltip" =>} shape here.
  module PreferencesMigration
    def self.migrate_general(saved, defaults)
      {}.tap do |migrated|
        saved.each do |key, value|
          migrated[key] = migrate_entry(key, value, defaults)
        end
      end
    end

    def self.migrate_entry(key, value, defaults)
      case value
      when Hash
        value
      when Array
        pair_entry(value, key, defaults)
      when true, false
        {"value" => value, "tooltip" => tooltip_for(key, defaults)}
      else
        defaults.fetch(key, {"value" => value, "tooltip" => ""})
      end
    end

    def self.pair_entry(value, key, defaults)
      if value.length == 2
        {"value" => value[1], "tooltip" => value[0]}
      else
        defaults.fetch(key, {"value" => value, "tooltip" => ""})
      end
    end

    def self.tooltip_for(key, defaults)
      entry = defaults[key]
      if entry.is_a?(Hash)
        entry.fetch("tooltip", "")
      else
        ""
      end
    end
  end

  # Ported from upstream src/core/preferences.py (PreferencesManager).
  #
  # The process-wide handle on the preferences of the game currently being
  # played. The window sets it when a game starts and clears it on the way
  # back to the main menu, so every other layer reads preferences through here
  # rather than being handed them.
  module PreferencesManager
    class << self
      def set_preferences(preferences)
        @preferences = preferences
      end

      def get_preferences = @preferences
    end
  end
end
