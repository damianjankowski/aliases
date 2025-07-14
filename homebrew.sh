#!/bin/bash
brew_clean_uninstall() {
  pkg="$1"

  if [[ -z "$pkg" ]]; then
    echo "No package name provided. Usage: brewcleanuninstall <package>"
    return 1
  fi

  if brew list --cask "$pkg" &>/dev/null; then
    brew uninstall --zap "$pkg"
  else
    brew uninstall "$pkg"
  fi

  brew autoremove
  brew cleanup
}

brew_maintenance() {
  echo "Starting comprehensive Homebrew maintenance..."
  
  echo "Updating Homebrew and formulae..."
  brew update
  
  echo "Upgrading all packages..."
  brew upgrade
  
  echo "Cleaning up old versions..."
  brew cleanup
  
  echo "Removing unused packages..."
  brew autoremove
  
  echo "Checking for broken dependencies..."
  brew doctor
  
  echo "Checking for outdated packages..."
  brew outdated
  
  echo "Completed!"
}

# ---- Aliases ----
alias fullbrew="brew_maintenance"
alias brewcleanuninstall='brew_clean_uninstall "$@"'
