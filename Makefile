.PHONY: all clean test

REGION := us-east-1
BUCKET_NAME := $(shell aws cloudformation list-exports --query 'Exports[?Name==`CloudwatchLogglySAMBucketName`].Value' --output text --region $(REGION))
TEMPLATE_HASH := $(shell md5 -q template.yml)

all: .build/$(TEMPLATE_HASH)/package.yml
	@sam publish --template .build/$(TEMPLATE_HASH)/package.yml --profile $(AWS_PROFILE) --region $(REGION)

.build/%/package.yml: .build .build/$(TEMPLATE_HASH)
	@sam build --use-container --profile $(AWS_PROFILE) --region $(REGION)
	@sam package --template-file template.yml --output-template-file $@ --s3-bucket $(BUCKET_NAME)

.build:
	@mkdir -p .build

.build/$(TEMPLATE_HASH):
	@mkdir -p .build/$(TEMPLATE_HASH)

test:
	@bundle exec rake

clean:
	@rm -rf .aws-sam
	@rm -rf .build
