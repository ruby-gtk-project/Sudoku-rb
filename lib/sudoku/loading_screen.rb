# frozen_string_literal: true

require "gtk4"
require "adwaita"

module Sudoku
  # Ported from upstream src/screens/loading_screen.py and
  # data/blueprints/loading-screen.blp.
  #
  # The stack page shown while a puzzle is being generated: a spinner, clamped
  # and centred.
  class LoadingScreen < Gtk::Box
    type_register

    SPINNER_SIZE = 48

    # A Gtk::Box subclass registered through the Ruby bindings takes no
    # constructor arguments, so the orientation is set as a property instead.
    def initialize
      super()
      self.orientation = :horizontal
      self.spacing = 0
      build
    end

    def build
      tap do |page|
        page.hexpand = true
        page.vexpand = true
        page.margin_bottom = 30
        page.append(clamp)

        clamp.tap do |area|
          area.child = content_box

          content_box.tap { |box| box.append(spinner) }
        end
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |area|
        area.maximum_size = 1200
        area.tightening_threshold = 300
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.margin_bottom = 20
        box.halign = :fill
        box.valign = :center
        box.hexpand = true
        box.vexpand = true
      end
    end

    def spinner
      @spinner ||= Adwaita::Spinner.new.tap do |wheel|
        wheel.halign = :center
        wheel.valign = :center
        wheel.set_size_request(SPINNER_SIZE, SPINNER_SIZE)
      end
    end
  end
end
