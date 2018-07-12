provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

data "aws_availability_zones" "available" {}

#ssh keys

resource "aws_key_pair" "aws_ssh_auth" {
  key_name  = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

#S3

resource "aws_iam_instance_profile" "s3_access" {
    name = "s3_access"
    role = "${aws_iam_role.s3_access.name}"
}

resource "aws_iam_role_policy" "s3_access_policy" {
    name = "s3_access_policy"
    role = "${aws_iam_role.s3_access.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
}

#IAM
resource "aws_iam_role" "s3_access" {
    name = "s3_access"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
  },
      "Effect": "Allow",
      "Sid": ""
      }
    ]
}
EOF
}

#VPC

resource "aws_vpc" "vpc" {
  cidr_block = "10.10.0.0/16"
}

#Interner Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
}


#Public routes
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
  tags {
    Name = "public"
  }
}


#Subnets
#!!!!!!NOTE!!!!!!!!!!!
#map_public_ip_on_launch is set to true to be able to connect to web instances directly via ssh

resource "aws_subnet" "public1" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.10.10.0/24"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[0]}"

    tags {
      Name = "public1"
    }
}

resource "aws_subnet" "public2" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.10.20.0/24"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[1]}"

    tags {
      Name = "public2"
    }
}

resource "aws_subnet" "public3" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.10.30.0/24"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[2]}"

    tags {
      Name = "public3"
    }
}

#Subnet Associations

resource "aws_route_table_association" "public1_rt_assoc" {
  subnet_id = "${aws_subnet.public1.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "public2_rt_assoc" {
  subnet_id = "${aws_subnet.public2.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "public3_rt_assoc" {
  subnet_id = "${aws_subnet.public3.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_db_subnet_group" "web_subnet_group" {
  name = "web_subnet_group"
  subnet_ids = ["${aws_subnet.public1.id}", "${aws_subnet.public2.id}", "${aws_subnet.public3.id}"]

  tags {
    Name = "web_subnet"
  }
}

#Security Groups

resource "aws_security_group" "public" {
  name = "sg_public"
  description = "SG for public access"
  vpc_id = "${aws_vpc.vpc.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["${var.my_external_ip}"]
  }

  #HTTP

  ingress {
    from_port   = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    #HTTPS

  ingress {
    from_port   = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound internet access

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "www" {
  bucket = "${var.s3bucket_name}"
  acl = "private"
  force_destroy = true
  tags {
    Name = "www bucket"
  }
}

#ELB

resource "aws_elb" "web_elb" {
  name = "web-elb"
  subnets = ["${aws_subnet.public1.id}", "${aws_subnet.public2.id}", "${aws_subnet.public3.id}"]
  security_groups = ["${aws_security_group.public.id}"]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
 # !!!required valid cert!!!
 #listener {
 #   instance_port = 443
 #   instance_protocol = "https"
 #   lb_port = 443
 #   lb_protocol = "https"
  #}

  health_check {
    healthy_threshold = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout = "${var.elb_timeout}"
    target = "HTTP:80/"
    interval = "${var.elb_interval}"
  }

  cross_zone_load_balancing = true
  idle_timeout = 300
  connection_draining = true
  connection_draining_timeout = 300

  tags {
    Name = "web-elb"
  }
}

#launch configuration

resource "aws_launch_configuration" "lc" {
  name_prefix = "lc-"
  image_id = "${var.web_ami}"
  instance_type = "${var.web_instance_type}"
  security_groups = ["${aws_security_group.public.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.s3_access.id}"
  key_name = "${aws_key_pair.aws_ssh_auth.id}"
  user_data = "${file("userdata")}"
  lifecycle {
    create_before_destroy = true
  }
}

#ASG


resource "aws_autoscaling_group" "asg" {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  name = "asg-${aws_launch_configuration.lc.id}"
  max_size = "${var.asg_max}"
  min_size = "${var.asg_min}"
  health_check_grace_period = "${var.asg_grace}"
  health_check_type = "${var.asg_hct}"
  desired_capacity = "${var.asg_cap}"
  force_delete = true
  load_balancers = ["${aws_elb.web_elb.id}"]
  vpc_zone_identifier = ["${aws_subnet.public1.id}", "${aws_subnet.public2.id}", "${aws_subnet.public3.id}"]
  launch_configuration = "${aws_launch_configuration.lc.name}"

  tag {
    key = "Name"
    value = "asg-web"
    propagate_at_launch = true
    }

  lifecycle {
    create_before_destroy = true
  }
}

output "web_entry_point" {
  value = "${aws_elb.web_elb.dns_name}"
}

