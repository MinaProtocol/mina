#!/bin/bash
set -eu

export HOMEBREW_NO_AUTO_UPDATE=1

# re-reads /usr/local/Homebrew if a cache has been put in place
brew update-reset

brew uninstall python@2 || true

brew bundle install --file=scripts/Brewfile

echo 'export PKG_CONFIG_PATH=$(brew --prefix openssl)/lib/pkgconfig' >> /Users/distiller/.bash_profile
echo 'export PATH="$(brew --prefix openssl)/bin:$PATH"' >> /Users/distiller/.bash_profile
