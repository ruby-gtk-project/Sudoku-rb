# frozen_string_literal: true

module Sudoku
  # Ported from upstream po/ — LINGUAS, POTFILES, sudokugame.pot and the
  # per-language catalogues — together with the gettext wiring upstream does in
  # src/sudokugame.in.
  #
  # Upstream leans on the whole GNU gettext toolchain: meson compiles every
  # po/<lang>.po into an installed binary catalogue and Python's
  # gettext.install() reads it back through libintl. A gem has no install-time
  # compile step and this port's runtime bundle is gtk4 + adwaita only, so the
  # shipped po/<lang>.po is read directly instead. The file format is the same
  # one msgmerge writes, so `rake pot` keeps working against these files.
  module Translations
    # The textdomain upstream uses, and so the basename of the template.
    DOMAIN = "sudokugame"

    # po/ sits next to lib/ in the repository, in the gem, and in the tree the
    # flake installs, so one relative path finds it everywhere.
    PO_DIR = File.expand_path("../../po", __dir__)

    LINGUAS = File.join(PO_DIR, "LINGUAS")

    # The separator gettext itself puts between a context and its message.
    CONTEXT_GLUE = "\u0004"

    # The environment variables gettext consults, in its order of precedence.
    # LANGUAGE holds a colon-separated list of preferences; the rest hold one
    # locale each.
    LOCALE_VARIABLES = ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"].freeze

    # Every catalogue declares UTF-8 and is written in it, so it is read in it
    # too: the locale this app runs under decides nothing about the encoding of
    # its own data files, and on a machine whose locales are not generated it
    # would otherwise be read as US-ASCII and raise on the first translated
    # line.
    ENCODING = "UTF-8"

    # A locale gettext treats as "no translation at all".
    UNTRANSLATED_LOCALES = ["C", "POSIX", ""].freeze

    ESCAPES = {
      '\\n'  => "\n",
      '\\t'  => "\t",
      '\\r'  => "\r",
      '\\"'  => '"',
      "\\\\" => "\\",
    }.freeze

    # Entries are separated by a blank line, which is what both msgmerge and
    # rxgettext write.
    ENTRY_SEPARATOR = /\n[ \t]*\n/

    FIELD_LINE = /\A(msgctxt|msgid|msgid_plural|msgstr)[ \t]+("(?:[^"\\]|\\.)*")\z/
    STRING_LINE = /\A("(?:[^"\\]|\\.)*")\z/

    class << self
      # The translation of a message, or the message itself when the catalogue
      # has no entry for it — gettext's own fallback, which is what keeps the
      # app readable with no catalogue installed at all.
      def translate(message) = catalogue.fetch(message, message)

      # A message disambiguated by a context, upstream's C_() — the shortcuts
      # dialog uses it so that, say, "Game" can be translated differently there
      # than anywhere else.
      def translate_in_context(context, message)
        catalogue.fetch([context, message].join(CONTEXT_GLUE), message)
      end

      # The parsed catalogue of the language in use: message => translation,
      # with contextual entries keyed the way gettext keys them. Empty when no
      # language applies, which is also the answer for an unreadable or absent
      # po/ directory.
      def catalogue
        @catalogue ||= parse(catalogue_source)
      end

      # The po file of the language in use, as text. Empty when no language
      # applies, and empty too when po/ is not in this tree — either way every
      # message stays in the English the sources are written in.
      def catalogue_source
        [language].compact
          .flat_map { |lang| Dir.glob(po_path(lang)) }
          .map { |path| File.read(path, encoding: ENCODING) }
          .join("\n\n")
      end

      # The language whose catalogue is in use: the first entry of the
      # environment's preference list this app has a po file for, by exact
      # match ("pt_BR") or by its language part ("pt"). nil when none matches.
      def language
        preferred_locales.lazy.flat_map { |locale| [locale, locale.split("_").first] }
          .find { |candidate| languages.include?(candidate) }
      end

      # The languages this app ships, as upstream's LINGUAS lists them.
      def languages
        @languages ||= linguas_lines.map { |line| line.sub(/#.*/, "").strip }.reject(&:empty?)
      end

      # LINGUAS as its lines — none at all when po/ is not in this tree, which
      # is how a checkout without the catalogue falls back to English. Glob
      # rather than File.exist?, because a glob of a path that is not there is
      # simply empty.
      def linguas_lines
        Dir.glob(LINGUAS).flat_map { |path| File.readlines(path, chomp: true, encoding: ENCODING) }
      end

      # The locales the environment asks for, most wanted first, stripped of
      # the encoding and modifier suffixes gettext also ignores when it looks
      # for a catalogue.
      def preferred_locales
        LOCALE_VARIABLES.filter_map { |name| ENV.fetch(name, nil) }
          .flat_map { |value| value.split(":") }
          .map { |locale| locale.sub(/[.@].*/, "") }
          .reject { |locale| UNTRANSLATED_LOCALES.include?(locale) }
      end

      def po_path(language) = File.join(PO_DIR, "#{language}.po")

      # The po file as a catalogue, each entry parsed on its own.
      def parse(text) = text.split(ENTRY_SEPARATOR).filter_map { |block| entry(block) }.to_h

      # One entry as the [key, translation] pair it contributes, or nil for an
      # entry that contributes none: the header, whose msgid is empty; an
      # untranslated message, whose msgstr is; a fuzzy one, which gettext also
      # ignores; and a plural one, which this catalogue never has — upstream's
      # sources mark no plural message.
      def entry(block)
        lines = block.lines.map(&:strip).reject(&:empty?)
        fields = fields_of(lines.reject { |line| line.start_with?("#") })
        message = fields["msgid"].to_s
        translation = fields["msgstr"].to_s
        usable = !fuzzy?(lines) && !fields.key?("msgid_plural") &&
          !message.empty? && !translation.empty?
        if usable
          [key_of(fields["msgctxt"], message), translation]
        end
      end

      def fuzzy?(lines)
        lines.any? { |line| line.start_with?("#,") && line.include?("fuzzy") }
      end

      def key_of(context, message)
        if context
          [context, message].join(CONTEXT_GLUE)
        else
          message
        end
      end

      # An entry's fields, with each field's continuation lines appended to it.
      # The accumulator carries the field the continuation lines belong to
      # alongside the fields themselves.
      def fields_of(lines)
        lines.each_with_object([{}, nil]) do |line, memo|
          case line
          when FIELD_LINE
            memo[1] = Regexp.last_match(1)
            memo[0][memo[1]] = unescape(Regexp.last_match(2))
          when STRING_LINE
            if memo[1]
              memo[0][memo[1]] += unescape(Regexp.last_match(1))
            end
          end
        end.first
      end

      def unescape(quoted)
        quoted.delete_prefix('"').delete_suffix('"').gsub(/\\[ntr"\\]/) { |match| ESCAPES.fetch(match) }
      end
    end
  end

  # The _() and p_() of upstream's Python sources and blueprints. Python's
  # gettext.install() puts _() in the builtins and Ruby has no such hook, so
  # the classes that show text mix this in instead. Including it extends the
  # includer too, because several of them hold their labels in constants built
  # while the class body is read.
  module Gettext
    def self.included(base) = base.extend(self)

    def _(message) = Translations.translate(message)

    def p_(context, message) = Translations.translate_in_context(context, message)
  end
end
