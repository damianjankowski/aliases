#!/bin/bash
# ---- Aliases ----

# Workflow Aliases
alias tfcheck="terraform fmt -recursive && terraform validate"
alias tfplan="terraform plan -out=tfplan"
alias tfapply="terraform apply tfplan"
alias tfaa="terraform apply -auto-approve"
