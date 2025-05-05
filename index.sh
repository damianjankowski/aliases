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

# ---- Helper functions ----
display_aliases_from_file() {
  local file="$1"
  local title="$2"
  
  echo -e "\n$title"
  echo "---------------------"
  grep "^alias" "$file" 2>/dev/null | sed 's/alias //;s/=/ → /'
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
  source ~/.zshrc
  echo "All aliases reloaded successfully"
}

alias_list_categories() {
  if [ ! -d "$ALIASES_DIR" ]; then
    echo "Error: Aliases directory not found"
    return 1
  fi

  echo "Available alias categories:"
  echo "system"
  ls -1 "$ALIASES_DIR"/*.sh 2>/dev/null | grep -v "index.sh" | sed 's/.*\///;s/\.sh$//' | sort
}

alias_list() {
  local system_file=~/.zshrc
  local system_title="System aliases (from ~/.zshrc)"
  
  if [ "$#" -eq 0 ]; then
    echo "All available aliases:"
    echo "---------------------"
    
    display_aliases_from_file "$system_file" "$system_title"
    
    for file in "$ALIASES_DIR"/*.sh; do
      if [ -f "$file" ] && [ "$file" != "$ALIASES_DIR/index.sh" ]; then
        category=$(basename "$file" .sh)
        display_aliases_from_file "$file" "Category: $category"
      fi
    done
    return 0
  fi
  
  if [ "$1" = "system" ]; then
    display_aliases_from_file "$system_file" "$system_title"
    return 0
  fi
  
  if [ -f "$ALIASES_DIR/$1.sh" ]; then
    display_aliases_from_file "$ALIASES_DIR/$1.sh" "Aliases for category $1"
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
