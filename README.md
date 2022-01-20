# Drift Management

## Setup infrastructure

### Stage 1 in the code

```
ssh-keygen -t rsa -C "nick@something.com" -f ./key.key
```

Confirm AWS region and add var in `teraform.tfvars`

```
aws configure get region
```
Apply the config and then review the state
```
terraform state list
data.aws_ami.ubuntu
aws_instance.example
aws_key_pair.deployer
aws_security_group.sg_ssh
```

## Introduce drift

Create a new SG and export it as an environment var
```
 export SG_ID=$(aws ec2 create-security-group --group-name "sg_web" --description "allow 8080" --output text)
```
Check the ID
```
echo $SG_ID
```

Next, create a new rule for your group to provide TCP access to the instance on port 8080 and associate the security group you created manually with the EC2 instance provisioned by Terraform.

```
aws ec2 authorize-security-group-ingress --group-name "sg_web" --protocol tcp --port 8080 --cidr 0.0.0.0/0

aws ec2 modify-instance-attribute --instance-id $(terraform output -raw instance_id) --groups $SG_ID
```

The instance's SSH security group has been replaced with a new security group that is not tracked in the Terraform state file.

## Run a refresh-only plan

If you suspect that your infrastructure configuration changed outside of the Terraform workflow use a `terraform plan -refresh-only` or `terraform apply -refresh-only` flag to inspect what the changes to your state file would be. This is safer than the refresh subcommand, which automatically overwrites your state file without displaying the updates.

Run `terraform plan -refresh-only` to determine the drift between your current state file and actual configuration.


Terraform has detected differences between the infrastructure and the current state, and sees that your original security group allowing access on port 80 is no longer attached to your EC2 instance. The refresh-only plan output indicates that Terraform will update your state file to modify the configuration of your EC2 instance to reflect the new security group with access on port 8080.

Apply these changes to make your state file match your real infrastructure, but not your Terraform configuration. Respond to the prompt with a yes.

```
terraform apply -refresh-only
...
Changes to Outputs:
  ~ security_groups = [
      - [
          - "sg-0bbc5710c6d31367e",
        ],
      + [
          + "sg-074cf59a5c533f3d1",
        ],
    ]
...
```
A refresh-only operation does not attempt to modify your infrastructure to match your Terraform configuration -- it only gives you the option to review and track the drift in your state file.

If you ran `terraform plan` or `terraform apply` without the `-refresh-only` flag now, Terraform would attempt to revert your manual changes. Instead, you will update your configuration to associate your EC2 instance with both security groups

## Add the security group to configuration

### Stage 2 in the code

Flip to the stage 2 commented lines.

## Import the new security group

Run `terraform import` to associate your resource definition with the security group created in the AWS
```
terraform import aws_security_group.sg_web $SG_ID
```
Import your security group rule.
```
terraform import aws_security_group_rule.sg_web "$SG_ID"_ingress_tcp_8080_8080_0.0.0.0/0
```
Run `terraform state list` to return the list of resources Terraform is managing, which now includes the imported resources.
```
terraform state list
data.aws_ami.ubuntu
aws_instance.example
aws_key_pair.deployer
aws_security_group.sg_ssh
aws_security_group.sg_web
aws_security_group_rule.sg_web
```
## Update the resources
Now that the sg_web security group is represented in state, re-run `terraform apply` to associate the SSH security group with your EC2 instance.

Notice how this updates your EC2 instance's security group to include both the security groups allowing SSH and 8080. Enter `yes` when prompted to confirm your changes.

```
terraform apply
aws_key_pair.deployer: Refreshing state... [id=deployer-key]
aws_security_group.sg_ssh: Refreshing state... [id=sg-0bbc5710c6d31367e]
aws_security_group.sg_web: Refreshing state... [id=sg-074cf59a5c533f3d1]
aws_security_group_rule.sg_web: Refreshing state... [id=sgrule-32579146]
aws_instance.example: Refreshing state... [id=i-0c1ffc3ff442ecda0]
...
```
## Access the instance

Confirm your instance allows SSH. Enter `yes` when prompted to connect to the instance.
```
ssh ubuntu@$(terraform output -raw public_ip) -i key.key
```
Confirm your instance allows port 8080 access.
```
curl $(terraform output -raw public_ip):8080
```
Clean up
```
terraform destroy
```
