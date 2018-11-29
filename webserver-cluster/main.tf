provider "aws" {
    region = "us-east-1"
}

resource "aws_launch_configuration" "taylors_config" {
    image_id = "ami-40d28157"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.instance.id}"]
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello world!!!" > index.html
                nohup busybox httpd -f - p "${var.server_port}" &
                EOF
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group" "instance" {
    name = "First-terraform-sec-group"

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

data "aws_availability_zones" "all" {}
resource "aws_autoscaling_group" "my_cluster" {
    launch_configuration = "${aws_launch_configuration.taylors_config.id}"
    availability_zones   = ["${data.aws_availability_zones.all.names}"]
    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-first"
        propagate_at_launch = true
    }
}
