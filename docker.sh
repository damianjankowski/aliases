#!/bin/bash

# ---- Helper functions for dangerous operations ----
docker_remove_containers() {
  local containers=$(docker ps -aq)
  if [ -z "$containers" ]; then
    echo "No containers to remove."
    return 0
  fi

  echo "This will remove ALL containers (stopped and running):"
  docker ps -a
  echo -e "\nAre you sure you want to remove all containers? (y/N)"
  read -r confirm
  if [[ $confirm =~ ^[Yy]$ ]]; then
    docker ps -aq | xargs -r docker rm
    echo "All containers removed."
  else
    echo "Operation cancelled."
  fi
}

docker_remove_images() {
  local images=$(docker images -q)
  if [ -z "$images" ]; then
    echo "No images to remove."
    return 0
  fi

  echo "This will remove ALL images:"
  docker images
  echo -e "\nAre you sure you want to remove all images? (y/N)"
  read -r confirm
  if [[ $confirm =~ ^[Yy]$ ]]; then
    docker images -q | xargs -r docker rmi
    echo "All images removed."
  else
    echo "Operation cancelled."
  fi
}

docker_system_clean() {
  echo "This will perform aggressive system cleanup (remove all unused containers, networks, images, and build cache):"
  docker system df
  echo -e "\nAre you sure you want to clean the entire Docker system? (y/N)"
  read -r confirm
  if [[ $confirm =~ ^[Yy]$ ]]; then
    docker system prune -a -f
    echo "Docker system cleaned."
  else
    echo "Operation cancelled."
  fi
}

docker_stop_all() {
  local running=$(docker ps -q)
  if [ -z "$running" ]; then
    echo "No running containers to stop."
    return 0
  fi

  echo "This will stop ALL running containers:"
  docker ps
  echo -e "\nAre you sure you want to stop all running containers? (y/N)"
  read -r confirm
  if [[ $confirm =~ ^[Yy]$ ]]; then
    docker stop $(docker ps -q)
    echo "All running containers stopped."
  else
    echo "Operation cancelled."
  fi
}

# ---- Aliases ----
alias dps="docker ps"
alias dpa="docker ps -a"
alias drun="docker run -it"
alias drm='docker_remove_containers'
alias drmi='docker_remove_images'
alias dclean="docker_system_clean"
alias dstop='docker_stop_all'
alias dlogs="docker logs -f"
alias dbuild="docker build -t"
