#!/bin/bash
# ---- Aliases ----
# alias tfi="terraform init"
# alias tfp="terraform plan"
# alias tfa="terraform apply"
# alias tfd="terraform destroy"
# alias tfv="terraform validate"
# alias tff="terraform fmt"
# alias tfo="terraform output"
# alias tfs="terraform state list"
# alias tfx="terraform state rm"
# alias tfimp="terraform import"

alias tfcheck="terraform fmt -recursive && terraform validate"              # Formats and validates all configuration files recursively

alias tfshowstate="terraform show -json | jq ."                             # Shows the Terraform state in JSON format, formatted with jq

alias tfgraph="terraform graph | dot -Tsvg -o graph.svg"                     # Creates a dependency graph and saves it as an SVG file
