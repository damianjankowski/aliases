#!/bin/bash
# ---- Aliases ----
alias tfi="terraform init"
alias tfp="terraform plan"
alias tfa="terraform apply"
alias tfd="terraform destroy"
alias tfv="terraform validate"
alias tff="terraform fmt"
alias tfo="terraform output"
alias tfs="terraform state list"
alias tfx="terraform state rm"
alias tfimp="terraform import"

alias tfplanf="terraform plan -input=false"                                 # Generates a plan without user input
alias tfapplyf="terraform apply -auto-approve"                              # Automatically applies the plan without approval

alias tfclean="rm -rf .terraform .terraform.lock.hcl && terraform init"     # Removes local state files and reinitializes the directory

alias tfstate="terraform state list"                                        # Lists all resources managed by Terraform in the state
alias tfcheck="terraform fmt -recursive && terraform validate"              # Formats and validates all configuration files recursively

alias tfgendocs="terraform-docs markdown . > README.md"                     # Generates markdown documentation and saves it to README.md

alias tfdebug="TF_LOG=DEBUG terraform apply"                                # Enables debug logging during the apply process
alias tfresetlog="TF_LOG="                                                  # Resets Terraform logging configuration

alias tfplanout="terraform plan -out=tfplan"                                # Generates and saves the plan to a file

alias tfshowstate="terraform show -json | jq ."                             # Shows the Terraform state in JSON format, formatted with jq

alias tfdrift="terraform plan -detailed-exitcode"                           # Returns a detailed exit code when there is configuration drift

alias tfapplyplan="terraform plan -out=tfplan && terraform apply tfplan"    # Creates a plan and immediately applies it

alias tfgraph="terraform graph | dot -Tsvg -o graph.svg"                     # Creates a dependency graph and saves it as an SVG file
