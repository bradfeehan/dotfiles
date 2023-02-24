# Custom spin-only configuration to run during setup

ln -sfv \
  "bradfeehan@spin.gitconfig" \
  "${HOME}/.gitconfig.d/local.gitconfig"

sudo apt-get install --assume-yes --no-install-recommends \
  fasd \
  libterm-readkey-perl \
;
