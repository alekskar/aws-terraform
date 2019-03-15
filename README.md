# OFJLDSJLSJLSJF:LSDFJF HHHH aws-terraform test
ASG 3web + S3 + VPC + IAM role

1. Generate ssh key with name `aws_key` and place is into terraform directory:

  -   `ssh-keygen -b 4096 -t rsa -C "your@identity"`

2. Rename **terraform.tfvarstemplace to terraform.tfvars** and fill in with appropriate values

3. Run `terraform apply` and enter you current external IP to access instances via ssh.
