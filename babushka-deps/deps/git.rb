# Git is a free and open source distributed version control system
# designed to handle everything from small to very large projects with
# speed and efficiency.
#
# http://git-scm.com/


dep 'git' do
  requires 'gitconfig.dotfile',
           'gitignore.global.dotfile'
end

# Main Git configuration file
dep 'gitconfig.dotfile'

# Global Git ignore file (for all projects)
dep 'gitignore.global.dotfile' do
  requires 'gitconfig.dotfile'
end
