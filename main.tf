provider "aws" {
  profile    = "${var.aws_profile}"
  region     = "${var.aws_region}"
}

terraform {
  backend "s3" {
    key    = "ec2-elasticsearch.tfstate"
  }
}

resource "aws_default_vpc" "default" {}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_default_vpc.default.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "fstehle" {
  key_name_prefix = "fstehle-"
  public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5LcxHdlrm90vCcj4fXZM5v6WtP/tNfB+vI37o2kEPDcOW2w9i3bf+R0wpMmAssfvailMBz90QJlBvPetcdxgpuaKF1OnzXHDngiHzKAp5wFHZ2XGQ0+Hvt/gpLNz/0J69GQk3nChrmgdYF31E6qMUHD/W81sU2OqvK8DuOCIqirm9NNMJME7kZTz1gboaJNBYlQnBFtSDk9PukpIDApaIuLQHuCMi+IbZEoA5TjdRIE2c1w4L2uZcuV9hv1W2Ue7blvf9QU6kXujgK676jjgEQcHKWopW+6BX1ACcjHt+Sf6vHjdqf37v5Rskq0Y0NfGy3KwVKzTP9Ou/ZMo/fnGL mail@fstehle.com"
}

resource "aws_instance" "some_instance" {
  ami                    = "ami-4d46d534"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.fstehle.key_name}"
  vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
  tags {
    Name = "elasticsearch"
    Role = "ec2-elasticsearch"
  }

  count = "2"

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -qq",
      "sudo apt-get install -qqy python-minimal",
    ]
    connection {
      user        = "ubuntu"
      private_key = "${file("${var.ssh_private_key}")}"
      agent       = false
    }
  }
}

output "instances" {
  value = "${aws_instance.some_instance.*.public_ip}"
}