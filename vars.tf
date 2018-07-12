variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
  default = "us-west-2"
}
variable "my_external_ip" {}
variable "key_name" {}
variable "public_key_path" {}
variable "s3bucket_name" {}
variable "web_ami" {}
variable "web_instance_type" {}
variable "elb_healthy_threshold" {}
variable "elb_unhealthy_threshold" {}
variable "elb_timeout" {}
variable "elb_interval" {}
variable "asg_max" {}
variable "asg_min" {}
variable "asg_grace" {}
variable "asg_hct" {}
variable "asg_cap" {}

