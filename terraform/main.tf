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

resource "aws_security_group" "elasticsearch_sg" {
  name        = "elasticsearch_sg"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_default_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    self        = true
  }
  ingress {
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    self        = true
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

resource "aws_iam_instance_profile" "elasticsearch_profile" {
  name  = "elasticsearch_profile"
  role = "${aws_iam_role.elasticsearch_data_role.name}"
}

resource "aws_iam_role" "elasticsearch_data_role" {
  name = "elasticsearch_data_role"
  path = "/"

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

resource "aws_iam_policy" "elasticsearch_role_policy" {
  name        = "elasticsearch_role_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "elasticsearch_role_policy_attachment" {
  role       = "${aws_iam_role.elasticsearch_data_role.name}"
  policy_arn = "${aws_iam_policy.elasticsearch_role_policy.arn}"
}

resource "aws_instance" "elasticsearch_data" {
  ami                    = "ami-4d46d534"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.fstehle.key_name}"
  vpc_security_group_ids = ["${aws_security_group.elasticsearch_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.elasticsearch_profile.id}"
  tags {
    Name = "elasticsearch-data-${count.index+1}"
    Role = "elasticsearch"
  }

  count = "2"

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.ssh_private_key}")}"
    agent       = false
  }

  provisioner "file" {
    source      = "ec2.fact.sh"
    destination = "/tmp/ec2.fact.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -qq",
      "sudo apt-get install -qqy python-minimal ec2-api-tools jq",
      "sudo mkdir -p /etc/ansible/facts.d",
      "sudo mv /tmp/ec2.fact.sh /etc/ansible/facts.d/ec2.fact",
      "sudo chmod +x /etc/ansible/facts.d/ec2.fact",
    ]
  }
}

resource "aws_instance" "elasticsearch_master" {
  ami                    = "ami-4d46d534"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.fstehle.key_name}"
  vpc_security_group_ids = ["${aws_security_group.elasticsearch_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.elasticsearch_profile.id}"
  tags {
    Name = "elasticsearch-master-${count.index+1}"
    Role = "elasticsearch"
  }

  count = "1"

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.ssh_private_key}")}"
    agent       = false
  }

  provisioner "file" {
    source      = "ec2.fact.sh"
    destination = "/tmp/ec2.fact.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -qq",
      "sudo apt-get install -qqy python-minimal ec2-api-tools jq",
      "sudo mkdir -p /etc/ansible/facts.d",
      "sudo mv /tmp/ec2.fact.sh /etc/ansible/facts.d/ec2.fact",
      "sudo chmod +x /etc/ansible/facts.d/ec2.fact",
    ]
  }
}

output "elasticsearch_data" {
  value = "${aws_instance.elasticsearch_data.*.public_ip}"
}

output "elasticsearch_master" {
  value = "${aws_instance.elasticsearch_master.*.public_ip}"
}