data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "template_file" "start" {
  template = file("${path.module}/start.sh")
}

resource "aws_security_group" "bastion" {
  name   = "${var.name}-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  tags = {
    Name = var.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "bastion" {
  count                       = var.enable ? 1 : 0
  ami                         = var.image_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = var.associate_public_ip_address

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_size           = "8"
    volume_type           = "gp2"
    delete_on_termination = "true"
  }

  tags = {
    Name = var.name
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "bastion" {
  count   = var.enable ? 1 : 0
  name    = "bastion"
  zone_id = var.route53_zone_id
  type    = "CNAME"
  ttl     = "300"
  records = [var.associate_public_ip_address ? aws_instance.bastion.0.public_dns : aws_instance.bastion.0.private_dns]
}