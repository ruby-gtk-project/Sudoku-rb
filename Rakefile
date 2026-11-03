# frozen_string_literal: true

# kettle-jem:freeze
# To retain chunks of comments & code during kettle-jem templating:
# Wrap custom sections with freeze markers (e.g., as above and below this comment chunk).
# kettle-jem will then preserve content between those markers across template runs.
# kettle-jem:unfreeze

# sudoku-rb Rakefile v7.1.28 - 2026-10-11
# Ruby 2.3 (Safe Navigation) or higher required
#
# See LICENSE.md for license information.
#
# Copyright (c) 2026 ruby-gtk-project (github.com)
#
# Expected to work in any project that uses Bundler.
#
# Sets up tasks for appraisal2, floss_funding, kettle-jem, kettle-dev, rspec, minitest, rubocop_gradual, reek, yard, and stone_checksums.
#
# rake appraisal:install                      # Install Appraisal gemfiles (initial setup...
# rake appraisal:reset                        # Delete Appraisal lockfiles (gemfiles/*.gemfile.lock)
# rake appraisal:generate                     # Generate Appraisal gemfiles without resolving...
# rake appraisal:update                       # Generate and update Appraisal gemfiles
# rake bench                                  # Run all benchmarks (alias for bench:run)
# rake bench:list                             # List available benchmark scripts
# rake bench:run                              # Run all benchmark scripts (skips on CI)
# rake build:generate_checksums               # Generate both SHA256 & SHA512 checksums i...
# rake bundle:audit:check                     # Checks the Gemfile.lock for insecure depe...
# rake bundle:audit:update                    # Updates the bundler-audit vulnerability d...
# rake ci:act[opt]                            # Run 'act' with a selected workflow
# rake coverage                               # Run specs w/ coverage and open results in...
# rake default                                # Default tasks aggregator
# rake install                                # Build and install sudoku-rb-1.0.0.gem in...
# rake install:local                          # Build and install sudoku-rb-1.0.0.gem in...
# rake kettle:jem:install                     # Internal target used by `kettle-jem install`
# rake kettle:jem:selftest                    # Self-test: template sudoku-rb against itse...
# rake kettle:jem:template                    # Internal target used by scoped `kettle-jem template --only`
# rake reek                                   # Check for code smells
# rake reek:update                            # Run reek and store the output into the RE...
# rake release[remote]                        # Create tag v1.0.0 and build and push kett...
# rake rubocop_gradual                        # Run RuboCop Gradual
# rake rubocop_gradual:autocorrect            # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual:autocorrect_all        # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual:check                  # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual:force_update           # Run RuboCop Gradual to force update the l...
# rake rubocop_gradual_debug                  # Run RuboCop Gradual
# rake rubocop_gradual_debug:autocorrect      # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual_debug:autocorrect_all  # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual_debug:check            # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual_debug:force_update     # Run RuboCop Gradual to force update the l...
# rake spec                                   # Run RSpec code examples
# rake test                                   # Run tests
# rake yard                                   # Generate YARD Documentation
# rake yard:lint                              # Lint YARD Documentation
#

# simplecov:disable
require "bundler/gem_tasks" if !Dir[File.join(__dir__, "*.gemspec")].empty?
# simplecov:enable

# Define a base default task early so other files can enhance it.
desc "Default tasks aggregator"
task :default do
  puts "Default task complete."
end

# Without this, a generated docs/ directory makes Rake resolve the bare
# name `docs` as an up-to-date file task, so `rake docs` exits 0 having
# regenerated nothing.
desc "Generate YARD documentation"
task docs: "yard"

# kettle-jem:freeze
### TRANSLATION TASKS
# po/ holds the gettext catalogue Sudoku::Translations reads at runtime.
# Upstream regenerates it through meson (scripts/update-po.sh drives
# `ninja sudokugame-update-po`); here the two steps are rake tasks.
#
# Both need the dev shell: rxgettext is the gettext gem's extractor — the only
# one that understands Ruby — and msgcat/msgmerge are GNU gettext.
#   nix develop --command rake pot
#   nix develop --command rake po
TEXTDOMAIN = "sudokugame"
PO_DIR = File.join(__dir__, "po")
POT_PATH = File.join(PO_DIR, "#{TEXTDOMAIN}.pot")
# The gem's version, read rather than required: requiring it would pull the app
# in, and with it gtk4.
POT_VERSION = File.read(File.join(__dir__, "lib/sudoku/rb/version.rb"))[/VERSION = "([^"]+)"/, 1]

# rxgettext ships with the gettext gem, which is not in this project's bundle:
# rake runs with GEM_PATH narrowed to the app's own gems, BUNDLE_GEMFILE
# pointed at their lockfile and BUNDLER_SETUP making every child process load
# bundler again, and under that environment the extractor cannot even be
# found. Clearing the lot hands each tool the plain dev shell it is installed
# into.
def unbundled_env
  ENV.keys.grep(/\ABUNDLER?_/).to_h { |name| [name, nil] }
    .merge("RUBYOPT" => nil, "RUBYLIB" => nil, "GEM_HOME" => nil, "GEM_PATH" => nil)
end

def gettext_sh(*command)
  puts(command.join(" "))
  system(unbundled_env, *command) || raise("#{command.first} failed")
end

# A list file — POTFILES or LINGUAS — as its entries, without the comments and
# blank lines both allow.
def gettext_list(name)
  File.readlines(File.join(PO_DIR, name), chomp: true)
    .map { |line| line.sub(/#.*/, "").strip }
    .reject(&:empty?)
end

desc "Extract po/#{TEXTDOMAIN}.pot from the sources listed in po/POTFILES"
task :pot do
  require "tmpdir"
  Dir.mktmpdir do |dir|
    extracted = File.join(dir, "#{TEXTDOMAIN}.pot")
    gettext_sh(
      "rxgettext",
      "--no-wrap",
      "--sort-by-file",
      "--package-name=#{TEXTDOMAIN}",
      "--package-version=#{POT_VERSION}",
      "--copyright-holder=sepehr-rs",
      "--copyright-year=2025",
      "--output=#{extracted}",
      *gettext_list("POTFILES"),
    )
    # rxgettext writes an empty "#:" line before each reference block and
    # spells every reference as a path relative to its own working directory;
    # and it fills Plural-Forms in with the placeholders msgfmt rejects, for a
    # catalogue whose sources mark no plural message at all.
    File.write(
      extracted,
      File.read(extracted)
        .gsub(/^#:[ \t]*\n/, "")
        .sub(/^"Plural-Forms: .*\n/, "")
        .lines
        .map { |line| line.start_with?("#: ") ? line.gsub(%r{\S*#{Regexp.escape(__dir__)}/}, "") : line }
        .join,
    )
    # msgcat rewraps at word boundaries, which rxgettext does not.
    gettext_sh(
      "msgcat",
      "--width=78",
      "--output-file=#{POT_PATH}",
      extracted,
    )
  end
end

desc "Merge po/#{TEXTDOMAIN}.pot into every language listed in po/LINGUAS"
task po: :pot do
  gettext_list("LINGUAS").each do |language|
    catalogue = File.join(PO_DIR, "#{language}.po")
    if File.exist?(catalogue)
      # No fuzzy matching: a guess drawn from a similar message reads as a
      # translation in every tool that shows the file, and the guesses this
      # catalogue drew were wrong often enough to be worse than nothing. A
      # message either keeps the translation it had or goes back to the
      # translators untranslated.
      gettext_sh(
        "msgmerge",
        "--quiet",
        "--update",
        "--backup=none",
        "--no-fuzzy-matching",
        "--width=78",
        catalogue,
        POT_PATH,
      )
    else
      gettext_sh(
        "msginit",
        "--no-translator",
        "--locale=#{language}",
        "--input=#{POT_PATH}",
        "--output-file=#{catalogue}",
      )
    end
    gettext_sh(
      "msgfmt",
      "--check",
      "--statistics",
      "--output-file=#{File::NULL}",
      catalogue,
    )
  end
end
# kettle-jem:unfreeze

# simplecov:disable
### MONOREPO FAMILY TASKS
if Dir.exist?(File.join(__dir__, "gems"))
  def family_gem_dirs
    Dir.glob(File.join(__dir__, "gems", "*", "*.gemspec"))
      .map { |path| File.dirname(path) }
      .uniq
      .sort_by { |path| File.basename(path) }
  end

  def run_kettle_family(*args)
    sh("bundle", "exec", "kettle-family", *args)
  end

  namespace :family do
    desc "List released Ruby subgems"
    task :list do
      family_gem_dirs.each { |path| puts File.basename(path) }
    end

    desc "Run release readiness checks for the Ruby gem family"
    task :readiness do
      run_kettle_family("check")
    end

    desc "Run tests for the Ruby gem family"
    task :test do
      run_kettle_family("test", "--execute")
    end

    desc "Run lint for the Ruby gem family"
    task :lint do
      run_kettle_family("lint", "--execute")
    end

    desc "Generate YARD docs for the Ruby gem family"
    task :docs do
      run_kettle_family("docs", "--execute")
    end

    desc "Report release state for the Ruby gem family"
    task :release_state do
      run_kettle_family("release-state")
    end

    desc "Run the Ruby gem family release planner"
    task :release do
      run_kettle_family("release")
    end

    desc "Execute the Ruby gem family release"
    task :release_execute do
      run_kettle_family("release", "--execute")
    end
  end
end
# simplecov:enable

# External gems that define tasks - add here!
begin
  require "kettle/dev"
  Kettle::Dev.install_tasks unless Kettle::Dev::RUNNING_AS == "rake"
rescue LoadError
  warn("NOTE: kettle-dev isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
end

### TEMPLATING TASKS
# These tasks are installed for the `kettle-jem` executable. Run full templating
# through `kettle-jem install`; use `kettle-jem template --only PATH` only for
# scoped file updates. The executable prepares the environment and then
# delegates here when rake orchestration is needed.
kettle_jem_selftest_unavailable_note = nil
begin
  require "kettle/jem"
  if Kettle::Jem.respond_to?(:install_tasks)
    Kettle::Jem.install_tasks
  else
    kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem #{Kettle::Jem::Version::VERSION} does not provide rake tasks in this environment"
  end
rescue LoadError
  kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem isn't installed, or is disabled for #{RUBY_VERSION} in the current environment"
end

if kettle_jem_selftest_unavailable_note
  desc("(stub) kettle:jem:selftest is unavailable")
  task("kettle:jem:selftest") do
    warn(kettle_jem_selftest_unavailable_note)
  end
end

### RELEASE TASKS
# Setup stone_checksums
begin
  require "stone_checksums"
rescue LoadError
  desc("(stub) build:generate_checksums is unavailable")
  task("build:generate_checksums") do
    warn("NOTE: stone_checksums isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
  end
end
