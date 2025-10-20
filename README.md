# terraform-vCD

## Create resources
```shell
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```


## reset stat
```shell
terraform stat list
terraform plan -refresh-only
terraform destroy -auto-approve
```

## remove the working dir cache
```shell
rm -f ./terraform
rm -f ./terraform.lock.hcl
terraform init -upgrade
```