#!/bin/bash
# ---- Docker aliases ----
alias dps="docker ps"
alias dpa="docker ps -a"
alias drun="docker run -it"
alias drm='docker ps -aq | xargs -r docker rm'
alias drmi='docker images -q | xargs -r docker rmi'
alias dclean="docker system prune -a -f"
alias dstop='docker stop $(docker ps -q)'
alias dlogs="docker logs -f"
alias dbuild="docker build -t"
