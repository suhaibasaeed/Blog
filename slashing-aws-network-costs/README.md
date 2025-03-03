# Slashing AWS Network Costs Blog
1. To get this Terraform code to work you will need to add the following block, to the `main.tf` file or another .tf file in the same directory such as `terraform.tf`. 
```
terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.38"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}
```
2. You'll also need to pass in your credentials somehow. One option is to paste in environment variables which are named as below, remember to wrap the value in quotes:
```
export AWS_ACCESS_KEY_ID=<your_access_key>
export AWS_SECRET_ACCESS_KEY=<your_secret_access_key>
export AWS_SESSION_TOKEN=<your_session_token>
```
