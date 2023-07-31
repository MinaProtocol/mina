#!/bin/bash
set -eu

export HOMEBREW_NO_AUTO_UPDATE=1

# re-reads /usr/local/Homebrew if a cache has been put in place
brew update-reset

brew uninstall python@2 || true

brew bundle install --file=scripts/Brewfile

echo 'you need to export the following environment variables in your shell configuration file (e.g. `.bashrc`, `.zshrc`, etc.)'

echo 'export PKG_CONFIG_PATH=$(brew --prefix openssl)/lib/pkgconfig'
echo 'export PATH="$(brew --prefix openssl)/bin:$PATH"'
echo 'export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"'
