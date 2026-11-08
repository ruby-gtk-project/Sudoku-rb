# frozen_string_literal: true

# Ported from upstream data/style.css and data/style-dark.css — there is no
# upstream test for the stylesheet (it ships as plain data, compiled into the
# gresource bundle by meson), so this is new coverage closing a gap named
# across prior parity rounds: `lib/sudoku/style.rb` had zero coverage of any
# kind, and no rule body (colors, sizes, margins) had ever been diffed
# against upstream's CSS.
#
# UPSTREAM_LIGHT/UPSTREAM_DARK below are verbatim copies of upstream's
# `data/style.css` and `data/style-dark.css` (read via `git show
# origin/main:data/style.css` against this port's own origin/main), kept here
# so the comparison does not depend on a sibling upstream checkout existing on
# disk at test time. `#parse_css` turns both the upstream text and
# `Sudoku::Style::LIGHT`/`DARK` into selector => normalized-declaration-body
# maps, and the examples diff those maps selector by selector — not just
# selector presence, but the actual rule bodies (colors, sizes, margins).

UPSTREAM_LIGHT = <<~CSS
  .sudoku-main-window {
      background-color: #e2b97d;
  }

  .icon-dropshadow {
  \t-gtk-icon-shadow: 0 1px 4px rgba(0,0,0,0.3), 0 3px 20px rgba(0,0,0,0.2);
  }

  #sudoku-parent-grid {
      padding: 50px;
  }

  #sudoku-parent-grid button {
      background-color: rgba(255, 245, 230, 0.6);
  }

  #sudoku-popover button {
      background-color: rgba(255, 227, 185, 0.85);
  }

  #sudoku-parent-grid button.toggle-active {
      background-color: #f9eed7;
      box-shadow: 0 0 10px #d2a56d66;
  }

  #sudoku-parent-grid button:hover {
      background-color: rgba(255, 245, 230, 0.85);
  }

  #sudoku-parent-grid button:checked {
      background-color: #f9eed7;
  }

  .entry-cell {
      color: rgba(28, 20, 15, 0.95);
      font-size: 20px;
  }

  .clue-cell {
      color: rgba(28, 20, 15, 0.65);
      font-size: 20px;
  }

  .sudoku-cell-button {
      min-width: 10px;
      min-height: 10px;
  }

  #sudoku-parent-grid button.entry-cell.correct {
      background-color: rgba(168, 208, 78, 0.55);
      transition: background-color 0.3s ease-in-out;
  }

  #sudoku-parent-grid button.entry-cell.wrong {
      background-color: rgba(226, 116, 74, 0.55);
  }

  #sudoku-parent-grid button.entry-cell.correct.highlight {
      background-color: rgba(190, 220, 90, 0.68);
  }

  #sudoku-parent-grid button.entry-cell.wrong.highlight {
      background-color: rgba(236, 136, 96, 0.68);
  }

  #sudoku-parent-grid button.conflict {
      background-color: rgba(226, 116, 74, 0.45);
      animation: pulse 3s;
  }

  #sudoku-parent-grid button.entry-cell.highlight,
  #sudoku-parent-grid button.clue-cell.highlight {
      background-color: #fff5e3;
      box-shadow: 0 0 10px #d2a56d79;
      transition: background-color 0.3s ease-in-out;
  }

  @keyframes pulse {
      20% { background-color: rgba(236, 136, 96, 0.68); }
      80% { background-color: rgba(236, 136, 96, 0.68); }
  }

  .note-cell-label {
      font-size: 11px;
      padding: 0.8px;
      color: rgba(28, 20, 15, 0.75);
  }

  .large  .entry-cell,
  .large  .clue-cell {
      font-size: 30px;
  }

  .large .note-cell-label {
      font-size: 15px;
      padding: 3px;
  }

  .compact-mode #sudoku-parent-grid {
      border-radius: 6px;
  }

  .compact-mode  .entry-cell,
  .compact-mode  .clue-cell {
      font-size: 20px;
  }

  .compact-mode .note-cell-label {
      font-size: 10px;
      padding: 0.4px;
  }

  .small-mode #sudoku-parent-grid {
      padding: 10px;
      border-radius: 6px;
  }

  .small-mode  .entry-cell,
  .small-mode .clue-cell {
      font-size: 17px;
  }

  .small-mode .note-cell-label {
      font-size: 7px;
      padding: 0.2px;
  }

  .corner-label {
      font-size: 13px;
      opacity: 0.5;
  }
CSS

UPSTREAM_DARK = <<~CSS
  .sudoku-main-window {
      background-color: #553525;
  }

  #sudoku-parent-grid button {
      background-color: rgba(236, 210, 180, 0.25);
  }

  #sudoku-parent-grid button.toggle-active {
      background-color: #e8cfae;
      box-shadow: 0 0 12px #e8cfae55;
  }

  #sudoku-parent-grid button:hover {
      background-color: rgba(236, 210, 180, 0.35);
  }

  #sudoku-parent-grid button:checked {
      background-color: #e8cfae;
  }

  #sudoku-parent-grid button.entry-cell.highlight,
  #sudoku-parent-grid button.clue-cell.highlight {
      background-color: #9b7f72;
      box-shadow: 0 0 12px #e0c6a333;
      transition: background-color 0.3s ease-in-out;
  }

  #sudoku-parent-grid button.entry-cell.correct {
      background-color: rgba(150, 190, 110, 0.50);
  }

  #sudoku-parent-grid button.entry-cell.wrong {
      background-color: rgba(220, 130, 100, 0.55);
  }

  #sudoku-parent-grid button.entry-cell.correct.highlight {
      background-color: rgba(172, 206, 126, 0.55);
  }

  #sudoku-parent-grid button.entry-cell.wrong.highlight {
      background-color: rgba(236, 146, 116, 0.68);
  }

  #sudoku-parent-grid button.conflict {
      background-color: rgba(220, 130, 100, 0.48);
  }

  @keyframes pulse {
      20% { background-color: rgba(236, 146, 116, 0.68); }
      80% { background-color: rgba(236, 146, 116, 0.68); }
  }

  .entry-cell {
      color: rgba(252, 244, 235, 1);
  }

  .clue-cell {
      color: rgba(252, 244, 235, 0.72);
  }

  .note-cell-label {
      color: #ebd6c0;
  }
CSS

# Splits a CSS text into selector => normalized-body pairs. Handles
# `@keyframes` blocks (whose body itself contains nested `{ }` blocks) by
# tracking brace depth rather than assuming one level of nesting.
def parse_css(text)
  rules = {}
  selector = +""
  i = 0
  length = text.length
  while i < length
    char = text[i]
    if char == "{"
      depth = 1
      j = i + 1
      while depth.positive?
        case text[j]
        when "{" then depth += 1
        when "}" then depth -= 1
        end
        j += 1
      end
      body = text[(i + 1)...(j - 1)]
      rules[selector.strip] = normalize_declarations(body)
      selector = +""
      i = j
    else
      selector << char
      i += 1
    end
  end
  rules
end

def normalize_declarations(body)
  body
    .lines
    .map { |line| line.gsub(/\s+/, " ").strip }
    .reject(&:empty?)
    .join("\n")
end

RSpec.describe Sudoku::Style do
  let(:upstream_light) { parse_css(UPSTREAM_LIGHT) }
  let(:upstream_dark) { parse_css(UPSTREAM_DARK) }
  let(:port_light) { parse_css(described_class::LIGHT) }
  let(:port_dark) { parse_css(described_class::DARK) }

  describe "light stylesheet" do
    it "declares exactly upstream's selectors" do
      expect(port_light.keys).to eq(upstream_light.keys)
    end

    it "matches upstream's declaration body for every selector" do
      upstream_light.each do |selector, body|
        expect(port_light[selector]).to eq(body), "selector #{selector.inspect} differs"
      end
    end
  end

  describe "dark stylesheet" do
    it "declares exactly upstream's selectors" do
      expect(port_dark.keys).to eq(upstream_dark.keys)
    end

    it "matches upstream's declaration body for every selector" do
      upstream_dark.each do |selector, body|
        expect(port_dark[selector]).to eq(body), "selector #{selector.inspect} differs"
      end
    end
  end

  describe ".light_provider" do
    it "builds a Gtk::CssProvider from LIGHT without raising" do
      expect(described_class.light_provider).to be_a(Gtk::CssProvider)
    end

    it "memoizes the same provider instance" do
      expect(described_class.light_provider).to be(described_class.light_provider)
    end
  end

  describe ".dark_provider" do
    it "builds a Gtk::CssProvider from DARK without raising" do
      expect(described_class.dark_provider).to be_a(Gtk::CssProvider)
    end

    it "memoizes the same provider instance" do
      expect(described_class.dark_provider).to be(described_class.dark_provider)
    end
  end

  describe ".install" do
    it "does nothing when given no display, rather than raising" do
      expect { described_class.install(nil) }.not_to raise_error
    end
  end
end
