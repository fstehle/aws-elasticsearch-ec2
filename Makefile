TERRAFORM_VERSION   = 0.11.3
AWS_REGION          = eu-west-1
AWS_PROFILE         = fstehle
TERRAFORM_S3_BUCKET = fstehle-ec2-elasticsearch-tf-s3-backend
SSH_PRIVATE_KEY     = $(HOME)/.ssh/id_rsa

TERRAFORM           = ./terraform
ANSIBLE             = ./venv/bin/ansible
ANSIBLE-PLAYBOOK    = ./venv/bin/ansible-playbook

venv: venv/bin/activate
venv/bin/activate: requirements.txt
	test -d venv || virtualenv --python=python3.6 venv
	venv/bin/pip install -Ur requirements.txt
	touch venv/bin/activate

$(TERRAFORM):
	curl -sSLfo terraform.zip https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$(shell uname -s | tr A-Z a-z)_$(shell uname -m | sed "s/x86_64/amd64/").zip
	unzip terraform.zip
	rm terraform.zip

$(ANSIBLE): venv
$(ANSIBLE-PLAYBOOK): venv

bootstrap: $(ANSIBLE) $(TERRAFORM)
	$(ANSIBLE) localhost -o -m s3_bucket -a "name=$(TERRAFORM_S3_BUCKET) profile=$(AWS_PROFILE) region=$(AWS_REGION) versioning=yes"
	$(TERRAFORM) init \
		-backend-config="bucket=$(TERRAFORM_S3_BUCKET)" \
		-backend-config="profile=$(AWS_PROFILE)" \
		-backend-config="region=$(AWS_REGION)"

infrastructure-apply: $(ANSIBLE) $(TERRAFORM)
	$(TERRAFORM) apply \
		-auto-approve \
		-var "aws_profile=$(AWS_PROFILE)" \
		-var "aws_region=$(AWS_REGION)"\
		-var "ssh_private_key=$(SSH_PRIVATE_KEY)"
	# Create ansible inventory
	INSTANCES=`$(TERRAFORM) output -json | jq -r '.instances.value[]'`; \
		  echo "[instances]\n$$INSTANCES" > inventory
	ANSIBLE_CONFIG=ansible.cfg $(ANSIBLE-PLAYBOOK) --inventory-file=inventory playbook.yml


.PHONY: bootstrap infrastructure-apply
