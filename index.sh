#!/bin/bash
# Main aliases loader

ALIASES_DIR="$HOME/src/infrastucture/bare-metal/aliases"
ALIAS_EDITOR="code"

# ---- Load all alias files ----
for file in $ALIASES_DIR/*.sh; do
  if [ "$file" != "$ALIASES_DIR/index.sh" ]; then
    source "$file"
  fi
done

# ---- Aliases management functions ----
alias_edit() {
  $ALIAS_EDITOR $ALIASES_DIR
}

alias_reload() {
  source "$ALIASES_DIR/index.sh"
  echo "All aliases reloaded"
}

alias_list_categories() {
  echo "Available alias categories:"
  ls -1 $ALIASES_DIR | grep .sh | sed 's/\.sh$//'
}

alias_list() {
  if [ "$#" -eq 0 ]; then
    alias
    return 0
  fi
  
  if [ -f "$ALIASES_DIR/$1.sh" ]; then
    echo "Aliases for category $1:"
    grep "^alias" "$ALIASES_DIR/$1.sh" | sed 's/alias //' | sed 's/=/ → /'
  else
    echo "Category $1 not found"
    return 1
  fi
}

# ---- Aliases for alias management ----
alias aedit="alias_edit"
alias areload="alias_reload"
alias alsc="alias_list_categories"
alias als="alias_list"
