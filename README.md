# terraform-vCD

## create resources
terraform init
terraform plan -out=tfplan
terraform apply tfplan


## reset stat
terraform stat list
terraform plan -refresh-only
terraform destroy -auto-approve

## remove the working dir cache
rm -f .\.terraform
rm -f .\.terraform.lock.hcl
terraform init -upgrade