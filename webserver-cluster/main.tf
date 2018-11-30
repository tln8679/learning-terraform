provider "aws" {
    region = "us-east-1"
}

# Create ALC
resource "aws_launch_configuration" "taylors_config" {
    image_id = "ami-40d28157"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.instance.id}"]
    # output helloworld to an index.html and start a webserver on port 8080
    user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
    # Terraform should create new servers before destroying the instances currently running
    lifecycle {
        create_before_destroy = true
    }
}

# Allow inbound access (tcp) on port 8080
resource "aws_security_group" "instance" {
    # I'm going to name all resources for this infra "WebCluster ^ X"
    name = "WebClusterInstance"

    ingress {
        from_port = "${var.server_port}"
        to_port = "${var.server_port}"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }
}


# Fetch all availabilty zones specific to my AWS account
data "aws_availability_zones" "all" {}
resource "aws_autoscaling_group" "my_cluster" {
    launch_configuration = "${aws_launch_configuration.taylors_config.id}"
    # Tell the ASG which availability zones the EC2's should be deplyed to
    availability_zones   = ["${data.aws_availability_zones.all.names}"]
    min_size = 2
    max_size = 10

    # Set load balance parameter to tell the ASG to register each instance in the ELB when booting
    load_balancers = ["${aws_elb.my_load_balancer.id}"]
    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-first"
        propagate_at_launch = true
    }
}

# Create Load Balancer to distribute traffic between the instances
resource "aws_elb" "my_load_balancer" {
    name = "WebCluster"
    availability_zones=["${data.aws_availability_zones.all.names}"]
    
    /* 
    * add a listener to specify port the ELB should listen on
    * and add a listener to route the request
    */
    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = "${var.server_port}"
        instance_protocol = "http"
    }
    
    # Needs to allow traffic in and out
    security_groups = ["${aws_security_group.elb.id}"]

    # Send health check to each ec2 every 30 seconds
    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        interval = 30
        target = "HTTP:${var.server_port}/"
    }
}

# Note: by default elbs don't allow incoming/outgoing traffic
resource "aws_security_group" "elb" {
    name = "WebClusterELB"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow outbound requests for the health checks
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}