#!/bin/bash

load_aliases() {
  if [ -z "${ALIASES_DIR:-}" ] || [ ! -d "$ALIASES_DIR" ]; then
    printf "Error: Aliases directory not found: %s\n" "${ALIASES_DIR:-<unset>}" >&2
    return 1
  fi

  local file
  for file in "$ALIASES_DIR"/*.sh; do
    if [ -f "$file" ] && [ "$file" != "$ALIASES_DIR/index.sh" ]; then
      source "$file" || printf "Warning: Failed to source %s\n" "$file" >&2
    fi
  done
}

display_aliases_from_file() {
  local file="$1"
  local title="$2"

  printf "\n%s\n" "$title"
  printf "%s\n" "---------------------"
  grep "^alias" "$file" 2>/dev/null | sed 's/alias //;s/=/ → /' | while IFS=' → ' read -r alias_name alias_cmd; do
    printf "  %-12s → %s\n" "$alias_name" "$alias_cmd"
  done
}

display_categorized_aliases() {
  local file="$1"
  local title="$2"

  printf "\n%s\n" "$title"
  printf "%s\n" "---------------------"

  local current_section=""
  local in_aliases_section=false
  local line

  while IFS= read -r line; do
    if [[ "$line" == "# ---- Aliases ----" ]]; then
      in_aliases_section=true
      continue
    fi

    if [ "$in_aliases_section" = false ]; then
      continue
    fi

    if [[ "$line" =~ ^#\ [A-Z] ]]; then
      if [ -n "$current_section" ]; then
        printf "\n"
      fi
      current_section="${line#\# }"
      printf "\n%s\n" "$current_section"
      continue
    fi

    if [[ "$line" =~ ^alias ]]; then
      local alias_name="${line#alias }"
      alias_name="${alias_name%%=*}"
      local alias_cmd="${line#*=}"
      alias_cmd="${alias_cmd#\'}"
      alias_cmd="${alias_cmd%\'}"
      printf "  %-12s → %s\n" "$alias_name" "$alias_cmd"
    fi
  done < "$file"
  printf "\n"
}

alias_edit() {
  if [ -z "${IDE_EDITOR:-}" ]; then
    printf "Error: IDE_EDITOR is not set\n" >&2
    return 1
  fi
  "$IDE_EDITOR" "$ALIASES_DIR"
}

alias_reload() {
  if [ -z "${ALIASES_DIR:-}" ] || [ ! -f "$ALIASES_DIR/index.sh" ]; then
    printf "Error: index.sh not found in %s\n" "${ALIASES_DIR:-<unset>}" >&2
    return 1
  fi
  source "$ALIASES_DIR/index.sh"
  printf "All aliases reloaded successfully\n"
}

alias_list_categories() {
  if [ -z "${ALIASES_DIR:-}" ] || [ ! -d "$ALIASES_DIR" ]; then
    printf "Error: Aliases directory not found\n" >&2
    return 1
  fi

  printf "Available alias categories:\n"
  printf "system\n"
  ls -1 "$ALIASES_DIR"/*.sh 2>/dev/null | grep -v "index.sh" | sed 's/.*\///;s/\.sh$//' | sort
}

alias_list() {
  local system_file="$HOME/.zshrc"
  local system_title="System aliases (from ~/.zshrc)"

  if [ "$#" -eq 0 ]; then
    printf "All available aliases:\n"
    printf "---------------------\n"

    display_aliases_from_file "$system_file" "$system_title"

    local file category
    for file in "$ALIASES_DIR"/*.sh; do
      if [ -f "$file" ] && [ "$file" != "$ALIASES_DIR/index.sh" ]; then
        category="$(basename "$file" .sh)"
        if grep -q "^# ---- Aliases ----" "$file" && grep -q "^# [A-Z]" "$file"; then
          display_categorized_aliases "$file" "Category: $category (with categories)"
        else
          display_aliases_from_file "$file" "Category: $category"
        fi
      fi
    done
    return 0
  fi

  if [ "$1" = "system" ]; then
    display_aliases_from_file "$system_file" "$system_title"
    return 0
  fi

  if [ -f "$ALIASES_DIR/$1.sh" ]; then
    if grep -q "^# ---- Aliases ----" "$ALIASES_DIR/$1.sh" && grep -q "^# [A-Z]" "$ALIASES_DIR/$1.sh"; then
      display_categorized_aliases "$ALIASES_DIR/$1.sh" "Aliases for category $1 (with categories)"
    else
      display_aliases_from_file "$ALIASES_DIR/$1.sh" "Aliases for category $1"
    fi
  else
    printf "Error: Category '%s' not found\n" "$1" >&2
    return 1
  fi
}

load_aliases

alias aedit="alias_edit"
alias areload="alias_reload"
alias alsc="alias_list_categories"
alias als="alias_list"
alias zshconfig="$IDE_EDITOR  $HOME/.zshrc"
alias ai="$IDE_EDITOR $AI_PATH"
