# Vim is an advanced text editor that seeks to provide the power of the
# de-facto Unix editor 'Vi', with a more complete feature set.
#
# http://www.vim.org/about.php


dep 'vim' do
  requires 'vimrc.dotfile'
end

# Requires Vundle, because it configures it
dep 'vimrc.dotfile' do
  requires 'bradfeehan:Vundle'
  after {
    log 'Installing Vundle bundles...'
    shell! 'vim', '+BundleInstall', '+qall'
  }
end
