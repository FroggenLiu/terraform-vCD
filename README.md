# terraform-vCD

## Install providers manually
``` shell
## Add the following to the ~/.terraformrc file.
provider_installation {
  filesystem_mirror {
    path    = "/root/.terraform.d/plugins"
  }
  direct {
    exclude = ["vmware/vcd"]
    exclude = ["vmware/nsxt"]
  }
}

## Create the folder structure as follows.
## Download the provider from https://releases.hashicorp.com/.
## Unzip the provider .tar file to the correct path.
root
└── .terrform.d
    └── plugins
        └── registry.terraform.io
            └── vmware ## put providers under here
                ├──nsxt ## this is provider nsxt
                │  └── 3.14.0 ## version
                │      └── linux_amd64 ## platform
                │          ├── CHANGELOG.md
                │          ├── LICENSE
                │          ├── README.md
                │          └── terraform-provider-nsxt_v3.10.0
                └──vcd 
                   └── 3.10.0
                       └── linux_amd64
                           ├── CHANGELOG.md
                           ├── LICENSE
                           ├── README.md
                           └── terraform-provider-vcd_v3.14.0
```
## list providers
```shell
terraform providers
```

## Create resources
```shell
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Destroy resources
```shell
terraform state list
terraform plan -refresh-only
terraform destroy -auto-approve
```

## Remove the working dir cache
```shell
rm -rf .terraform/ .terraform.lock.hcl terraform.tfstate 1111 terraform.tfstate.backup
terraform init -upgrade
```