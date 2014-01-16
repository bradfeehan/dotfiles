# Zsh is a shell designed for interactive use, although it is also a
# powerful scripting language. Many of the useful features of bash,
# ksh, and tcsh were incorporated into zsh; many original features were
# added.
#
# http://www.zsh.org/


dep 'zsh' do
  requires 'zlogin.dotfile',
           'zpreztorc.dotfile',
           'zprofile.dotfile',
           'zshenv.dotfile',
           'zshrc.dotfile'
end

dep 'zlogin.dotfile'
dep 'zprofile.dotfile'
dep 'zshenv.dotfile'

# The following dotfiles require Prezto, as they configure it
dep 'zpreztorc.dotfile' do
  requires 'bradfeehan:Prezto'
end

dep 'zshrc.dotfile' do
  requires 'bradfeehan:Prezto'
end
