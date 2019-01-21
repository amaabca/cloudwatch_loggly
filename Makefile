.PHONY: all clean test

TEMPLATE_HASH := $(shell md5 -q template.yml)
PARAMETERS := $(shell cat .params.private)

all: .params.private .build/$(TEMPLATE_HASH)/package.yml
	@sam deploy --template-file .build/$(TEMPLATE_HASH)/package.yml --stack-name cloudwatch-to-loggly --capabilities CAPABILITY_IAM --parameter-overrides $(PARAMETERS)

.params.private:
	@echo 'A .params.private file was not found in the project root. Please create this file.'
	@touch .params.private
	@exit 1

.build/%/package.yml: .build .build/$(TEMPLATE_HASH)
	@sam build --use-container
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
