#!/bin/bash
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
  
  for var in $(env | grep -E "^GITLAB_.*_TOKEN=" | cut -d= -f1); do
    unset "$var"
  done
  
  echo "All token environment variables have been cleared"
}

# GitHub token management
github_token() {
  local action="$1"
  local value="$2"
  
  case "$action" in
    set)
      set_token "github" "Enter GitHub token:"
      ;;
    get)
      security find-generic-password -a "$USER" -s "github_token" -w
      ;;
    use)
      get_token "github" "GITHUB_TOKEN"
      ;;
    delete)
      security delete-generic-password -a "$USER" -s "github_token" 2>/dev/null
      if [ $? -eq 0 ]; then
        echo "GitHub token deleted from Keychain"
      else
        echo "Error: Failed to delete GitHub token"
        return 1
      fi
      ;;
    *)
      echo "Usage: github_token [set|get|use|delete]"
      ;;
  esac
}

# GitLab token management 
gitlab_token() {
  local context="$1"
  local action="$2"
  
  if [ -z "$context" ]; then
    echo "Usage: gitlab_token CONTEXT [set|get|use|delete]"
    echo "  CONTEXT - Token context (e.g., work, personal)"
    return 1
  fi
  
  case "$action" in
    set)
      set_token "gitlab_$context" "Enter GitLab token for $context:"
      ;;
    get)
      security find-generic-password -a "$USER" -s "gitlab_${context}_token" -w
      ;;
    use)
      get_token "gitlab_$context" "GITLAB_TOKEN"
      ;;
    delete)
      security delete-generic-password -a "$USER" -s "gitlab_${context}_token" 2>/dev/null
      if [ $? -eq 0 ]; then
        echo "GitLab $context token deleted from Keychain"
      else
        echo "Error: Failed to delete GitLab $context token"
        return 1
      fi
      ;;
    *)
      echo "Usage: gitlab_token $context [set|get|use|delete]"
      ;;
  esac
}

# Gitlab envs
gitlab_token_priv() {
  gitlab_token "priv" "$@"
}

gitlab_token_work() {
  gitlab_token "work" "$@"
}

# Dynatrace OAuth token management
dynatrace_oauth_token() {
  local action="$1"
  
  case "$action" in
    set)
      set_token "dynatrace-automation-client-id" "Enter Dynatrace Automation Client ID:"
      set_token "dynatrace-automation-client-secret" "Enter Dynatrace Automation Client Secret:"
      ;;
    get)
      get_token "dynatrace-automation-client-id" "DYNATRACE_CLIENT_ID"
      get_token "dynatrace-automation-client-secret" "DYNATRACE_CLIENT_SECRET"
      ;;
    use)
      get_token "dynatrace-automation-client-id" "DYNATRACE_CLIENT_ID"
      get_token "dynatrace-automation-client-secret" "DYNATRACE_CLIENT_SECRET"
      ;;
    delete)
      security delete-generic-password -a "$USER" -s "dynatrace-automation-client-id" 2>/dev/null
      security delete-generic-password -a "$USER" -s "dynatrace-automation-client-secret" 2>/dev/null
      if [ $? -eq 0 ]; then
        echo "Dynatrace OAuth tokens deleted from Keychain"
      else
        echo "Error: Failed to delete Dynatrace OAuth tokens"
        return 1
      fi
      ;;
    *)
      echo "Usage: dynatrace_oauth_token [set|get|use|delete]"
      ;;
  esac
}

# Dynatrace API token management
dynatrace_api_token() {
  local action="$1"
  
  case "$action" in
    set)
      set_token "dynatrace-api-token" "Enter Dynatrace API Token:"
      ;;
    get)
      get_token "dynatrace-api-token" "DYNATRACE_API_TOKEN"
      ;;
    use)
      get_token "dynatrace-api-token" "DYNATRACE_API_TOKEN"
      ;;
    delete)
      security delete-generic-password -a "$USER" -s "dynatrace-api-token" 2>/dev/null
      if [ $? -eq 0 ]; then
        echo "Dynatrace API token deleted from Keychain"
      else
        echo "Error: Failed to delete Dynatrace API token"
        return 1
      fi
      ;;
    *)
      echo "Usage: dynatrace_api_token [set|get|use|delete]"
      ;;
  esac
}

# ---- Aliases ----
alias getgithubtoken='github_token get'
alias setgithubtoken='github_token set'
alias usegithubtoken='github_token use'
alias deletegithubtoken='github_token delete'

alias getgitlabtokenpriv='gitlab_token_priv get'
alias setgitlabtokenpriv='gitlab_token_priv set'
alias usegitlabtokenpriv='gitlab_token_priv use'
alias deletegitlabtokenpriv='gitlab_token_priv delete'

alias getgitlabtokenwork='gitlab_token_work get'
alias setgitlabtokenwork='gitlab_token_work set'
alias usegitlabtokenwork='gitlab_token_work use'
alias deletegitlabtokenwork='gitlab_token_work delete'

alias getdynatraceoauthtoken='dynatrace_oauth_token get'
alias setdynatraceoauthtoken='dynatrace_oauth_token set'
alias usedynatraceoauthtoken='dynatrace_oauth_token use'
alias deletedynatraceoauthtoken='dynatrace_oauth_token delete'

alias getdynatraceapitoken='dynatrace_api_token get'
alias setdynatraceapitoken='dynatrace_api_token set'
alias usedynatraceapitoken='dynatrace_api_token use'
alias deletedynatraceapitoken='dynatrace_api_token delete'

alias cleantokens='cleanup_tokens'
