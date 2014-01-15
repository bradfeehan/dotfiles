# Installs a particular dotfile
#
#   * provides:    The name of the dotfile (the leading dot, if
#                  present, can be omitted)
#   * source:      The directory containing the source dotfile
#                  (optional, defaults to the "dotfiles" directory in
#                  the root of this project)
#   * destination: The directory where the dotfile should be put
#                  (optional, defaults to the current user's home
#                  directory)
meta :dotfile do
  accepts_value_for :provides, :basename
  accepts_value_for :source, (__FILE__.p.parent.parent.parent / 'dotfiles').to_s
  accepts_value_for :destination, '~'

  # Searches for the file, both with and without a leading dot
  def filename
    @filename ||= calculate_filename
  end

  # Calculates the filename, which is cached in #filename
  def calculate_filename
    candidates = ['', '.'].map {|prefix| "#{prefix}#{provides}" }
    candidates.find {|test| (source.p / test).exists? }.tap do |found|
      unmeetable! "No dotfile '#{provides}' in #{source}" unless found
    end
  end

  # Retrieves the path to the "target" dotfile (destination)
  def target
    @target ||= destination.p / filename
  end

  # Retrieves the path to the "origin" dotfile (source)
  def origin
    @origin ||= source.p / filename
  end

  template {
    met? { target.symlink? && File.readlink(target).p == origin }
    meet {
      if target.exists? || target.symlink?
        unmeetable! <<-END.gsub(/ {10}/, '')
          Dotfile target '#{target}' exists, but it isn't a symlink
          pointing to the origin '#{origin}'.
        END
      end

      log_block "Symlinking #{origin} to #{target}" do
        target.parent.create_dir
        File.symlink origin, target
      end
    }
  }
end
