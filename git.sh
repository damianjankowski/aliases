#!/bin/bash
# ---- Aliases ----
alias gp="git push"
alias gca='git commit --amend'
alias gcb='git checkout -b'
alias gs="git status"
alias gl="git log --oneline --graph --decorate"
alias ga="git add"
alias gc="git commit -m"
alias gd="git diff"
alias gpl="git pull"

gitlab_clone() {
  local repo_url="$1"
  local target_dir="${2:-$(basename "$repo_url" .git)}"

  if [ -z "$GITLAB_TOKEN" ]; then
    echo "Token not loaded"
    return 1
  fi

  local domain=$(echo "$repo_url" | cut -d'/' -f3)
  local path=$(echo "$repo_url" | cut -d'/' -f4-)

  /usr/bin/git clone "https://oauth2:$GITLAB_TOKEN@$domain/$path" "$target_dir"
}

alias gclone="gitlab_clone"
