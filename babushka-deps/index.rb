# Main dep, sets up all dotfiles in this project
dep 'dotfiles' do
  requires 'git',
           'vim',
           'zsh'
end
