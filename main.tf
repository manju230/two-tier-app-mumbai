##############VPC######################

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "dev"
    Terraform   = "true"
  }
}

################PUBLIC SUBNET##########################################
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = var.public_subnet
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id

  }
  tags = {
    Name      = "tf_public_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "two_tier_igw"
  }
}

######################Private##############################

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = false

  tags = {
    Name        = var.private_subnet
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id

  }
  tags = {
    Name      = "tf_private_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet.id
}

#Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  vpc = true
  tags = {
    Name = "two_tier_igw_eip"
  }
}

#Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  subnet_id     = aws_subnet.private_subnet.id
  allocation_id = aws_eip.nat_gateway_eip.id
  tags = {
    Name = "demo_nat_gateway"
  }
}

###################################SG###########################

resource "aws_security_group" "allow_tls" {
  name        = "allow_ssh_http"
  description = "allow_ssh_http"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow_ssh_http"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "allow_ssh_http"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}
##############################EC2############################


# resource "aws_instance" "myec2" {
#   ami                         = "ami-06fc49795bc410a0c"
#   subnet_id                   = aws_subnet.public_subnet.id
#   instance_type               = "t2.micro"
#   vpc_security_group_ids      = [aws_security_group.allow_tls.id]
#   key_name                    = "Golden Key"
#   associate_public_ip_address = true
#   user_data                   = file("install_apache.sh")

#   tags = {
#     "Name" = "apache"
#   }
# }

#############################ALB##################################

resource "aws_alb" "myalb" {
  name               = "myalb2apache"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  #subnets              = ["subnet-04136b737fa9def38", "subnet-00c9124901631c329"]

  subnet_mapping {
    subnet_id = aws_subnet.public_subnet.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.private_subnet.id
  }

  tags = {
    name = "myalb"
  }
}

resource "aws_alb_listener" "alb-http-listener" {
  load_balancer_arn = aws_alb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.mytg1.arn
  }

}

resource "aws_alb_target_group" "mytg1" {
  name        = "mytg1"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/"


  }

}

# resource "aws_alb_target_group_attachment" "mytg1" {
#   target_group_arn = aws_alb_target_group.mytg1.arn
#   target_id        = aws_instance.myec2.id
#   port             = 80

# }

###################################ASG#############################

# Define the launch configuration
resource "aws_launch_configuration" "myasg-1" {
  name_prefix     = "myasg-1"
  image_id        = "ami-06fc49795bc410a0c"
  instance_type   = "t2.micro"
  key_name        = "Golden Key"
  user_data       = file("install_apache.sh")
  security_groups = [aws_security_group.allow_tls.id]
}

# Define the Auto Scaling Group
resource "aws_autoscaling_group" "asg-group1" {
  name_prefix          = "asg-group1"
  launch_configuration = aws_launch_configuration.myasg-1.name
  min_size             = 1
  max_size             = 2
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.public_subnet.id]
  target_group_arns    = [aws_alb_target_group.mytg1.arn]

  # Define the scaling policies
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "example-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "asg-attach" {
  autoscaling_group_name = aws_autoscaling_group.asg-group1.name
  alb_target_group_arn   = aws_alb_target_group.mytg1.arn
}