AWS_DEFAULT_REGION := us-east-1

export AWS_DEFAULT_REGION


CLOUDWATCH_FROM_DATE = $(shell ./scripts/determine-cloudwatch-from-date-based-on-existing-bigquery-data.sh)
CLOUDWATCH_TO_DATE = $(shell date '+%Y-%m-%d')
CLOUDWATCH_TARGET_DIR = ./logs/cloudwatch
CLOUDWATCH_JSONL_FILE = ./logs/ingress.jsonl
CLOUDWATCH_JSONL_GZ_FILE = $(CLOUDWATCH_JSONL_FILE).gz
CLOUDWATCH_JSONL_SCHEMA_FILE = $(CLOUDWATCH_JSONL_FILE).bq-schema.json


.PHONY: clean download-events-from-s3 ship-events-to-s3 update* bq-update-groups

.env:
	cp .env.example .env

clean:
	rm -r venv

venv: requirements.txt requirements.build.txt
	python3 -m venv venv
	./venv/bin/pip install -r requirements.build.txt
	./venv/bin/pip install -r requirements.txt

ship-events-to-s3:
	kubectl run --rm --attach ship-events \
		--image=amazon/aws-cli:2.4.23 \
		--command=true \
		--restart=Never \
		--env=PGHOST=$$(kubectl get secret hive-prod-rds-postgres -o json | jq -r '.data."postgresql-host"'| base64 -d) \
		--env=PGDATABASE=$$(kubectl get secret hive-prod-rds-postgres -o json | jq -r '.data."postgresql-database"'| base64 -d) \
		--env=PGUSER=$$(kubectl get secret hive-prod-rds-postgres -o json | jq -r '.data."postgresql-username"'| base64 -d) \
		--env=PGPASSWORD=$$(kubectl get secret hive-prod-rds-postgres -o json | jq -r '.data."postgresql-password"'| base64 -d) \
		--env=AWS_ACCESS_KEY_ID=$$(kubectl get secret sciety-events-shipper-aws-credentials -o json | jq -r '.data."id"'| base64 -d) \
		--env=AWS_SECRET_ACCESS_KEY=$$(kubectl get secret sciety-events-shipper-aws-credentials -o json | jq -r '.data."secret"'| base64 -d) \
		-- \
		bash -c 'yum install --assumeyes --quiet postgresql \
			&& psql -c "copy (select json_agg(events) from events) To STDOUT;" > ./events.json \
			&& sed --in-place --expression="s/\\\\n//g" ./events.json \
			&& aws s3 cp "./events.json" "s3://sciety-data-extractions/events.json" \
		'

download-events-from-s3:
	aws s3 cp "s3://sciety-data-extractions/events.json" "./events.json"

.gs-events-json-to-jsonl:
	cat ./events.json \
		| jq -c '.[]' \
		> ./events.jsonl \

.bq-generate-schema: venv .gs-events-json-to-jsonl
	cat ./events.jsonl \
		| venv/bin/generate-schema > events.bq-schema.json

.bq-update-events: .gs-events-json-to-jsonl .bq-generate-schema
	bq load \
		--project_id=elife-data-pipeline \
		--replace \
		--schema=events.bq-schema.json \
		--source_format=NEWLINE_DELIMITED_JSON \
		de_proto.sciety_event_v1 \
		./events.jsonl

.upload-events-from-db-to-bigquery:
	$(MAKE) ship-events-to-s3
	$(MAKE) download-events-from-s3
	$(MAKE) .bq-update-events

.cloudwatch-show-info:
	@echo "From: $(CLOUDWATCH_FROM_DATE)"
	@echo "To: $(CLOUDWATCH_TO_DATE)"
	@echo "Target dir: $(CLOUDWATCH_TARGET_DIR)"

.export-and-download-from-cloudwatch:
	rm -rf "$(CLOUDWATCH_TARGET_DIR)"
	./scripts/export-and-download-from-cloudwatch.sh \
		"$(CLOUDWATCH_FROM_DATE)" \
		"$(CLOUDWATCH_TO_DATE)" \
		"$(CLOUDWATCH_TARGET_DIR)"

.convert-gzipped-cloudwatch-logs-to-jsonl-gz:
	./scripts/convert-gzipped-cloudwatch-logs-to-jsonl-gz.sh \
		"$(CLOUDWATCH_TARGET_DIR)" \
		"$(CLOUDWATCH_JSONL_GZ_FILE)"

.generate-schema-for-cloudwatch-jsonl-gz-file: venv
	zcat "$(CLOUDWATCH_JSONL_GZ_FILE)" \
		| venv/bin/generate-schema \
		> "$(CLOUDWATCH_JSONL_SCHEMA_FILE)"

.upload-ingress-jsonl-gz-to-bigquery:
	bq load \
		--project_id=elife-data-pipeline \
		--noreplace \
		--schema="$(CLOUDWATCH_JSONL_SCHEMA_FILE)" \
		--schema_update_option=ALLOW_FIELD_ADDITION \
		--source_format=NEWLINE_DELIMITED_JSON \
		de_proto.sciety_ingress_v1 \
		"$(CLOUDWATCH_JSONL_GZ_FILE)"

.do-upload-ingress-logs-from-cloudwatch-to-bigquery:
	$(MAKE) .cloudwatch-show-info
	$(MAKE) .export-and-download-from-cloudwatch
	$(MAKE) .convert-gzipped-cloudwatch-logs-to-jsonl-gz
	$(MAKE) .generate-schema-for-cloudwatch-jsonl-gz-file
	$(MAKE) .upload-ingress-jsonl-gz-to-bigquery

.upload-ingress-logs-from-cloudwatch-to-bigquery:
	@if [ "$(CLOUDWATCH_FROM_DATE)" = "$(CLOUDWATCH_TO_DATE)" ]; then \
		echo "Not uploading cloudwatch ingress logs to BigQuery because it has already ran today."; \
	else \
		$(MAKE) CLOUDWATCH_FROM_DATE="$(CLOUDWATCH_FROM_DATE)" \
			.do-upload-ingress-logs-from-cloudwatch-to-bigquery; \
	fi

update-datastudio: \
	.upload-events-from-db-to-bigquery \
	.upload-ingress-logs-from-cloudwatch-to-bigquery

bq-update-groups:
	cat "data/sciety-groups.json" \
		| jq -c '.[]' \
		| tee "data/sciety-groups.jsonl" \
		&& bq load \
		--project_id=elife-data-pipeline \
		--autodetect \
		--replace \
		--source_format=NEWLINE_DELIMITED_JSON \
		de_proto.sciety_group_v1 \
		"data/sciety-groups.jsonl"

bq-update-known-users:
	cat "data/sciety-known-users.json" \
		| jq -c '.[]' \
		| tee "data/sciety-known-users.jsonl" \
		&& bq load \
		--project_id=elife-data-pipeline \
		--autodetect \
		--replace \
		--source_format=NEWLINE_DELIMITED_JSON \
		de_proto.sciety_known_user_v1 \
		"data/sciety-known-users.jsonl"
