# aws-elasticsearch-ec2

Sample project to run Elasticsearch on EC2 using Terraform & Ansible

## Dependencies

* make
* curl
* Python 3.6
* virtualenv

## Configuration

In the top of the Makefile...

## Bootstrap of Terraform

This step creates the S3 bucket for the Terraform state and initializes Terraform

```
make bootstrap
```

## Deployment

```
make infrastructure-apply
```