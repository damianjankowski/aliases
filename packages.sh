#!/usr/bin/env bash

_brew_update() {
    printf "\n🍺 Updating Homebrew...\n"
    brew update 
}

_brew_cleanup() {
    printf "\n🍺 Cleaning up old versions and cache...\n"
    brew cleanup -s 
}

_brew_autoremove() {
    printf "\n🍺 Removing unused dependencies...\n"
    brew autoremove 
}

_brew_doctor() {
    printf "\n🍺 Running diagnostics...\n"
    brew doctor 
}

brewup() {
    printf "🍺 Starting Homebrew formulae maintenance...\n"
    
    _brew_update 
    
    printf "\n🍺 Upgrading formulae...\n"
    brew upgrade 

    _brew_cleanup 
    _brew_autoremove 
    _brew_doctor
    
    printf "\n🍺 Homebrew formulae maintenance complete!\n"
}

brewupcask() {
    printf "🍺 Starting Homebrew cask maintenance...\n"
    
    _brew_update || return 1

    printf "\n🍺 Upgrading casks...\n"
    brew upgrade --cask --greedy

    _brew_cleanup 
    _brew_autoremove 
    _brew_doctor
    
    printf "\n🍺 Homebrew cask maintenance complete!\n"
}

pipxup() {
    printf "🐍 Starting pipx maintenance...\n"

    printf "\n🐍 Installed pipx packages:\n"
    pipx list --short
    
    printf "\n🐍 Upgrading pipx packages...\n"
    pipx upgrade-all

    printf "\n🐍 Pipx maintenance complete!\n"
}

alias brewupdate='brewup'
alias brewupdatecask='brewupcask'
alias pipxupdate='pipxup'
