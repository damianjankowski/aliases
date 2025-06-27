#!/bin/bash
if [[ "$(uname)" != "Darwin" ]]; then
    return
fi

# ---- Token aliases  ----

set_token() {
  local token_name="$1"
  local prompt_message="${2:-Enter token value:}"
  local keychain_name="${token_name}_token"
  
  echo "$prompt_message"
  read -s token_value
  
  if [ -z "$token_value" ]; then
    echo "Token cannot be empty. Please try again."
    return 1
  fi
  
  security add-generic-password -a "$USER" -s "$keychain_name" -w "$token_value" -U
  echo "Token '$token_name' has been stored in Keychain"
}

get_token() {
  local token_name="$1"
  local env_var_name="$2"
  local keychain_name="${token_name}_token"
  
  local token_value
  token_value=$(security find-generic-password -a "$USER" -s "$keychain_name" -w 2>/dev/null)
  
  if [ -z "$token_value" ]; then
    echo "Error: Token '$token_name' not found in Keychain."
    return 1
  fi
  
  export "$env_var_name"="$token_value"
  echo "Token '$token_name' loaded into $env_var_name"
}

delete_token() {
  local token_name="$1"
  local keychain_name="${token_name}_token"
  
  security delete-generic-password -a "$USER" -s "$keychain_name" 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "Token '$token_name' deleted from Keychain"
  else
    echo "Error: Failed to delete token '$token_name'"
    return 1
  fi
}

manage_token() {
  local token_name="$1"
  local action="$2"
  local env_var_name="$3"
  local prompt_message="$4"
  
  case "$action" in
    set)
      set_token "$token_name" "$prompt_message"
      ;;
    get)
      echo "Are you sure you want to display the token in the terminal? (y/N)"
      read confirm
      if [[ $confirm =~ ^[Yy]$ ]]; then
        security find-generic-password -a "$USER" -s "${token_name}_token" -w
      else
        echo "Token display cancelled"
      fi
      ;;
    use)
      get_token "$token_name" "$env_var_name"
      ;;
    delete)
      delete_token "$token_name"
      ;;
    *)
      echo "Usage: manage_token TOKEN_NAME [set|get|use|delete] [ENV_VAR_NAME] [PROMPT_MESSAGE]"
      ;;
  esac
}

cleanup_tokens() {
  local tokens=(
    GITHUB_TOKEN
    GITLAB_TOKEN
    DYNATRACE_CLIENT_ID
    DYNATRACE_CLIENT_SECRET
    DYNATRACE_API_TOKEN
    DYNATRACE_AUTOMATION_CLIENT_ID
    DYNATRACE_AUTOMATION_CLIENT_SECRET
  )
  
  for token in "${tokens[@]}"; do
    unset "$token"
  done
  
  echo "All token environment variables have been cleared"
}

# ---- Aliases ----
# GITHUB
alias getgithubtoken='manage_token github get GITHUB_TOKEN'
alias setgithubtoken='manage_token github set GITHUB_TOKEN "Enter GitHub token:"'
alias usegithubtoken='manage_token github use GITHUB_TOKEN'
alias deletegithubtoken='manage_token github delete'

# GITLAB PRIV
alias getgitlabtokenpriv='manage_token gitlab_priv get GITLAB_TOKEN'
alias setgitlabtokenpriv='manage_token gitlab_priv set GITLAB_TOKEN "Enter GitLab private token:"'
alias usegitlabtokenpriv='manage_token gitlab_priv use GITLAB_TOKEN'
alias deletegitlabtokenpriv='manage_token gitlab_priv delete'

# GITLAB WORK
alias getgitlabtokenwork='manage_token gitlab_work get GITLAB_TOKEN'
alias setgitlabtokenwork='manage_token gitlab_work set GITLAB_TOKEN "Enter GitLab work token:"'
alias usegitlabtokenwork='manage_token gitlab_work use GITLAB_TOKEN'
alias deletegitlabtokenwork='manage_token gitlab_work delete'

# DYNATRACE OAUTH
alias getdynatraceoauthtoken='manage_token dynatrace-automation-client-id get DYNATRACE_CLIENT_ID && manage_token dynatrace-automation-client-secret get DYNATRACE_CLIENT_SECRET'
alias setdynatraceoauthtoken='manage_token dynatrace-automation-client-id set DYNATRACE_CLIENT_ID "Enter Dynatrace Automation Client ID:" && manage_token dynatrace-automation-client-secret set DYNATRACE_CLIENT_SECRET "Enter Dynatrace Automation Client Secret:"'
alias usedynatraceoauthtoken='manage_token dynatrace-automation-client-id use DYNATRACE_CLIENT_ID && manage_token dynatrace-automation-client-secret use DYNATRACE_CLIENT_SECRET'
alias deletedynatraceoauthtoken='manage_token dynatrace-automation-client-id delete && manage_token dynatrace-automation-client-secret delete'

# DYNATRACE API DEV
alias getdynatraceapitokendev='manage_token dynatrace-api-token get DYNATRACE_API_TOKEN'
alias setdynatraceapitokendev='manage_token dynatrace-api-token set DYNATRACE_API_TOKEN "Enter Dynatrace API Token:"'
alias usedynatraceapitokendev='manage_token dynatrace-api-token use DYNATRACE_API_TOKEN'
alias deletedynatraceapitokendev='manage_token dynatrace-api-token delete'

# DYNATRACE API PROD
alias getdynatraceapitokenprod='manage_token dynatrace-api-token-prod get DYNATRACE_API_TOKEN'
alias setdynatraceapitokenprod='manage_token dynatrace-api-token-prod set DYNATRACE_API_TOKEN "Enter Dynatrace API Token:"'
alias usedynatraceapitokenprod='manage_token dynatrace-api-token-prod use DYNATRACE_API_TOKEN'
alias deletedynatraceapitokenprod='manage_token dynatrace-api-token-prod delete'

alias cleantokens='cleanup_tokens'
