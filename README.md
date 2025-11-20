# terraform-vCD

## Folder structure currently
```shell
TERRAFORM-VCD/
├── main.tf                # calls your modules
├── providers.tf           # defines vCD + NSX-T providers
├── variables.tf           # global + shared variables
├── terraform.tfvars       # actual variable values (like passwords, org names)
└── modules/
    └── org/
        ├── main.tf        # logic to create Org, VDC, T1 gateway
        ├── variables.tf   # declares module input variables
        └── outputs.tf     # outputs IDs / paths to root
```


## Install providers manually
``` shell
## Add the following to the ~/.terraformrc file.
provider_installation {
  filesystem_mirror {
    path    = "/root/.terraform.d/plugins"
  }
  direct {
    exclude = [
        "registry.terraform.io/vmware/vcd",
        "registry.terraform.io/vmware/nsxt",
        "registry.terraform.io/hashicorp/time"
    ]
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
            │    ├──nsxt ## this is provider nsxt
            │    │  └── 3.14.0 ## version
            │    │      └── linux_amd64 ## platform
            │    │          ├── CHANGELOG.md
            │    │          ├── LICENSE
            │    │          ├── README.md
            │    │          └── terraform-provider-nsxt_v3.10.0
            │    └──vcd 
            │       └── 3.10.0
            │           └── linux_amd64
            │               ├── CHANGELOG.md
            │               ├── LICENSE
            │               ├── README.md
            │               └── terraform-provider-vcd_v3.14.0
            └── hashicorp
                 └──time 
                    └── 0.13.1
                        └── linux_amd64
                            ├── LICENSE
                            └── terraform-provider-time_v0.13.1_x5
```
## list providers
```shell
terraform providers
```

## add new providers
```shell
terraform init -upgrade
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
rm -rf .terraform/ .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
```