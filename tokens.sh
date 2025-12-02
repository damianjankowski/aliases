#!/bin/bash
if [[ "$(uname)" != "Darwin" ]]; then
  return
fi

set_token() {
  local token_name="$1"
  local prompt_message="${2:-Enter token value:}"
  local keychain_name="${token_name}_token"
  printf "%s\n" "$prompt_message"
  read -r -s token_value
  if [ -z "$token_value" ]; then
    printf "Token cannot be empty. Please try again.\n" >&2
    return 1
  fi
  security add-generic-password -a "$USER" -s "$keychain_name" -w "$token_value" -U
  printf "Token '%s' has been stored in Keychain\n" "$token_name"
}

get_token() {
  local token_name="$1"
  local env_var_name="$2"
  local keychain_name="${token_name}_token"
  local token_value
  token_value="$(security find-generic-password -a "$USER" -s "$keychain_name" -w 2>/dev/null)"
  if [ -z "$token_value" ]; then
    printf "Error: Token '%s' not found in Keychain.\n" "$token_name" >&2
    return 1
  fi
  export "$env_var_name"="$token_value"
  printf "Token '%s' loaded into %s\n" "$token_name" "$env_var_name"
}

delete_token() {
  local token_name="$1"
  local keychain_name="${token_name}_token"
  security delete-generic-password -a "$USER" -s "$keychain_name" 2>/dev/null
  if [ $? -eq 0 ]; then
    printf "Token '%s' deleted from Keychain\n" "$token_name"
  else
    printf "Error: Failed to delete token '%s'\n" "$token_name" >&2
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
      printf "Are you sure you want to display the token in the terminal? (y/N)\n"
      read -r confirm
      if [[ $confirm =~ ^[Yy]$ ]]; then
        security find-generic-password -a "$USER" -s "${token_name}_token" -w
      else
        printf "Token display cancelled\n"
      fi
      ;;
    use)
      get_token "$token_name" "$env_var_name"
      ;;
    delete)
      delete_token "$token_name"
      ;;
    *)
      printf "Usage: manage_token TOKEN_NAME [set|get|use|delete] [ENV_VAR_NAME] [PROMPT_MESSAGE]\n"
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
    DYNATRACE_ACCOUNT_ID
  )
  local token
  for token in "${tokens[@]}"; do
    unset "$token"
  done
  printf "All token environment variables have been cleared\n"
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
alias getdynatraceoauthtoken='manage_token dynatrace-automation-client-id get DYNATRACE_CLIENT_ID && manage_token dynatrace-automation-client-secret get DYNATRACE_CLIENT_SECRET && manage_token dynatrace-automation-dynatrace-account get DYNATRACE_ACCOUNT_ID'
alias setdynatraceoauthtoken='manage_token dynatrace-automation-client-id set DYNATRACE_CLIENT_ID "Enter Dynatrace Automation Client ID:" && manage_token dynatrace-automation-client-secret set DYNATRACE_CLIENT_SECRET "Enter Dynatrace Automation Client Secret:" && manage_token dynatrace-automation-dynatrace-account set DYNATRACE_ACCOUNT_ID "Enter Dynatrace Account ID:"'
alias usedynatraceoauthtoken='manage_token dynatrace-automation-client-id use DYNATRACE_CLIENT_ID && manage_token dynatrace-automation-client-secret use DYNATRACE_CLIENT_SECRET && manage_token dynatrace-automation-dynatrace-account use DYNATRACE_ACCOUNT_ID'
alias deletedynatraceoauthtoken='manage_token dynatrace-automation-client-id delete && manage_token dynatrace-automation-client-secret delete && manage_token dynatrace-automation-dynatrace-account delete'

# DYNATRACE URL PROD
alias getdynatraceurlprod='manage_token dynatrace-url-prod get DYNATRACE_URL_PROD'
alias setdynatraceurlprod='manage_token dynatrace-url-prod set DYNATRACE_URL_PROD "Enter Dynatrace URL:"'
alias usedynatraceurlprod='manage_token dynatrace-url-prod use DYNATRACE_URL_PROD'
alias deletedynatraceurlprod='manage_token dynatrace-url-prod delete'

# DYNATRACE URL DEV
alias getdynatraceurldev='manage_token dynatrace-url-dev get DYNATRACE_URL_DEV'
alias setdynatraceurldev='manage_token dynatrace-url-dev set DYNATRACE_URL_DEV "Enter Dynatrace URL:"'
alias usedynatraceurldev='manage_token dynatrace-url-dev use DYNATRACE_URL_DEV'
alias deletedynatraceurldev='manage_token dynatrace-url-dev delete'

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

# PAGER DUTY
alias getpagerduty='manage_token pagerduty get PAGERDUTY_TOKEN'
alias setpagerduty='manage_token pagerduty set PAGERDUTY_TOKEN "Enter PagerDuty work token:"'
alias usepagerduty='manage_token pagerduty use PAGERDUTY_TOKEN'
alias deletepagerduty='manage_token pagerduty delete'

alias cleantokens='cleanup_tokens'
