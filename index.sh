#!/bin/bash
# Main aliases loader

# Configuration
ALIASES_DIR="$HOME/src/infrastucture/bare-metal/aliases"
ALIAS_EDITOR="code"

# ---- Load all alias files ----
load_aliases() {
  if [ ! -d "$ALIASES_DIR" ]; then
    echo "Error: Aliases directory not found: $ALIASES_DIR"
    return 1
  fi

  for file in "$ALIASES_DIR"/*.sh; do
    if [ -f "$file" ] && [ "$file" != "$ALIASES_DIR/index.sh" ]; then
      source "$file" || echo "Warning: Failed to source $file"
    fi
  done
}

# ---- Aliases management functions ----
alias_edit() {
  if [ -z "$ALIAS_EDITOR" ]; then
    echo "Error: ALIAS_EDITOR is not set"
    return 1
  fi
  $ALIAS_EDITOR "$ALIASES_DIR"
}

alias_reload() {
  if [ ! -f "$ALIASES_DIR/index.sh" ]; then
    echo "Error: index.sh not found in $ALIASES_DIR"
    return 1
  fi
  source "$ALIASES_DIR/index.sh"
  echo "All aliases reloaded successfully"
}

alias_list_categories() {
  if [ ! -d "$ALIASES_DIR" ]; then
    echo "Error: Aliases directory not found"
    return 1
  fi

  echo "Available alias categories:"
  ls -1 "$ALIASES_DIR"/*.sh 2>/dev/null | grep -v "index.sh" | sed 's/.*\///;s/\.sh$//' | sort
}

alias_list() {
  if [ "$#" -eq 0 ]; then
    # Show all aliases with category information
    echo "All available aliases:"
    echo "---------------------"
    for file in "$ALIASES_DIR"/*.sh; do
      if [ -f "$file" ] && [ "$file" != "$ALIASES_DIR/index.sh" ]; then
        category=$(basename "$file" .sh)
        echo -e "\nCategory: $category"
        echo "---------------------"
        grep "^alias" "$file" | sed 's/alias //;s/=/ → /'
      fi
    done
    return 0
  fi
  
  if [ -f "$ALIASES_DIR/$1.sh" ]; then
    echo "Aliases for category $1:"
    echo "---------------------"
    grep "^alias" "$ALIASES_DIR/$1.sh" | sed 's/alias //;s/=/ → /'
  else
    echo "Error: Category '$1' not found"
    return 1
  fi
}

# ---- Initialize aliases ----
load_aliases

# ---- Aliases for alias management ----
alias aedit="alias_edit"
alias areload="alias_reload"
alias alsc="alias_list_categories"
alias als="alias_list"
