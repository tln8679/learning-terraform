output "elb_dns_name" {
    value = "${aws_elb.my_load_balancer.dns_name}"
}