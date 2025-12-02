#!/bin/bash

confirm_action() {
  local prompt="$1"
  local confirm
  printf "\n%s (y/N) " "$prompt"
  read -r confirm
  [[ $confirm =~ ^[Yy]$ ]]
}

# Commands
docker_system_clean() {
  printf "This will perform aggressive system cleanup (remove all unused containers, networks, images, and build cache):\n"
  docker system df

  if confirm_action "Are you sure you want to clean the entire Docker system?"; then
    docker system prune -a -f
    printf "Docker system cleaned.\n"
  else
    printf "Operation cancelled.\n"
  fi
}

docker_stop_all() {
  local running
  running="$(docker ps -q)"
  if [ -z "$running" ]; then
    printf "No running containers to stop.\n"
    return 0
  fi

  printf "This will stop ALL running containers:\n"
  docker ps

  if printf "%s\n" "$running" | xargs docker stop; then
    printf "All running containers stopped.\n"
  else
    printf "Failed to stop some containers.\n" >&2
    return 1
  fi
}

# ---- Aliases ----
alias dclean="docker_system_clean"
alias dstop='docker_stop_all'
