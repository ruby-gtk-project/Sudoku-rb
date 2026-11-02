# frozen_string_literal: true

require "adwaita"

module Sudoku
  # Ported from upstream data/blueprints/shortcuts-dialog.blp.
  #
  # The keyboard shortcuts window, built from the same sections and
  # accelerators the blueprint declares.
  #
  # Adwaita::ShortcutsDialog cannot be subclassed through the Ruby bindings
  # (type registration is refused), so the dialog is assembled here and handed
  # back ready to present.
  module ShortcutsDialog
    SECTIONS = [
      [
        "Game",
        [
          ["Move Between Cells", "Up Down Left Right"],
          ["Jump Between Blocks", "<Primary>Up Down Left Right"],
        ],
      ],
      [
        "Pencil",
        [
          ["Pencil Mode", "P"],
          ["Auto Pencil Marks", "<Shift>P"],
          ["Place Pencil Mark", "<Primary>1...9"],
        ],
      ],
      [
        "Input",
        [
          ["Open Number Pop-Up", "Return"],
        ],
      ],
      [
        "General",
        [
          ["Show Shortcuts", "<Primary>question"],
          ["Back to Main Menu", "<Primary>M"],
          ["How to Play", "F1"],
          ["Quit", "<Primary>Q <Primary>W"],
        ],
      ],
    ].freeze

    def self.build
      Adwaita::ShortcutsDialog.new.tap do |dialog|
        SECTIONS.each do |(title, items)|
          dialog.add(section(title, items))
        end
      end
    end

    def self.section(title, items)
      Adwaita::ShortcutsSection.new.tap do |group|
        group.title = title
        items.each { |(item_title, accelerator)| group.add(item(item_title, accelerator)) }
      end
    end

    def self.item(title, accelerator) = Adwaita::ShortcutsItem.new(title, accelerator)
  end
end
