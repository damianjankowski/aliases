#!/bin/bash

# Utilities
docker_is_available() {
  command -v docker >/dev/null 2>&1
}

confirm_action() {
  local prompt="$1"
  local confirm
  printf "\n%s (y/N) " "$prompt"
  read -r confirm
  [[ $confirm =~ ^[Yy]$ ]]
}

# Commands
docker_remove_containers() {
  if ! docker_is_available; then
    printf "Error: docker is not installed or not in PATH.\n" >&2
    return 127
  fi

  local containers
  containers="$(docker ps -aq)"
  if [ -z "$containers" ]; then
    printf "No containers to remove.\n"
    return 0
  fi

  printf "This will remove ALL containers (stopped and running):\n"
  docker ps -a

  if confirm_action "Are you sure you want to remove all containers?"; then
    if printf "%s\n" "$containers" | xargs docker rm; then
      printf "All containers removed.\n"
    else
      printf "Failed to remove some containers.\n" >&2
      return 1
    fi
  else
    printf "Operation cancelled.\n"
  fi
}

docker_remove_images() {
  if ! docker_is_available; then
    printf "Error: docker is not installed or not in PATH.\n" >&2
    return 127
  fi

  local images
  images="$(docker images -q)"
  if [ -z "$images" ]; then
    printf "No images to remove.\n"
    return 0
  fi

  printf "This will remove ALL images:\n"
  docker images

  if confirm_action "Are you sure you want to remove all images?"; then
    if printf "%s\n" "$images" | xargs docker rmi; then
      printf "All images removed.\n"
    else
      printf "Failed to remove some images.\n" >&2
      return 1
    fi
  else
    printf "Operation cancelled.\n"
  fi
}

docker_system_clean() {
  if ! docker_is_available; then
    printf "Error: docker is not installed or not in PATH.\n" >&2
    return 127
  fi

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
  if ! docker_is_available; then
    printf "Error: docker is not installed or not in PATH.\n" >&2
    return 127
  fi

  local running
  running="$(docker ps -q)"
  if [ -z "$running" ]; then
    printf "No running containers to stop.\n"
    return 0
  fi

  printf "This will stop ALL running containers:\n"
  docker ps

  if confirm_action "Are you sure you want to stop all running containers?"; then
    if printf "%s\n" "$running" | xargs docker stop; then
      printf "All running containers stopped.\n"
    else
      printf "Failed to stop some containers.\n" >&2
      return 1
    fi
  else
    printf "Operation cancelled.\n"
  fi
}

# ---- Aliases ----
alias dps="docker ps"
alias dpa="docker ps -a"
alias drun="docker run -it"
alias drm="docker rm"
alias drmi="docker rmi"
alias drmall='docker_remove_containers'
alias drmiall='docker_remove_images'
alias dclean="docker_system_clean"
alias dstop='docker_stop_all'
alias dlogs="docker logs -f"
alias dbuild="docker build -t"
alias dexec="docker exec -it"
alias dstart="docker start"
alias dimages="docker images"
alias dvols="docker volume ls"
alias dnet="docker network ls"
