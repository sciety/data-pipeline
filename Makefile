AWS_DEFAULT_REGION := us-east-1

export AWS_DEFAULT_REGION


CLOUDWATCH_FROM_DATE = $(shell ./scripts/determine-cloudwatch-from-date-based-on-existing-bigquery-data.sh)
CLOUDWATCH_TO_DATE = $(shell date '+%Y-%m-%d')
CLOUDWATCH_TARGET_DIR = ./logs/cloudwatch
CLOUDWATCH_JSONL_FILE = ./logs/ingress.jsonl
CLOUDWATCH_JSONL_SCHEMA_FILE = $(CLOUDWATCH_JSONL_FILE).bq-schema.json


.PHONY: clean download-events-from-s3 ship-events-to-s3 update*

.env:
	cp .env.example .env

clean:
	rm -r venv

venv: requirements.txt requirements.build.txt
	python3 -m venv venv
	./venv/bin/pip install -r requirements.build.txt
	./venv/bin/pip install -r requirements.txt

update-db-dump:
	kubectl run psql \
	--image=postgres:12.3 \
	--env=PGHOST=$$(kubectl get secret hive-prod-rds-postgres -o json | jq -r '.data."postgresql-host"'| base64 -d) \
	--env=PGDATABASE=$$(kubectl get secret hive-prod-rds-postgres -o json | jq -r '.data."postgresql-database"'| base64 -d) \
	--env=PGUSER=$$(kubectl get secret hive-prod-rds-postgres -o json | jq -r '.data."postgresql-username"'| base64 -d) \
	--env=PGPASSWORD=$$(kubectl get secret hive-prod-rds-postgres -o json | jq -r '.data."postgresql-password"'| base64 -d) \
	-- sleep 60
	kubectl wait --for condition=Ready pod psql
	kubectl exec psql -- psql -c "copy (select json_agg(events) from events) To STDOUT;" | sed -e 's/\\n//g' > ./events.json
	kubectl delete --wait=false pod psql

ship-events-to-s3:
	kubectl run --rm --attach ship-events \
		--image=amazon/aws-cli:2.4.23 \
		--command=true \
		--restart=Never \
		-- \
		aws s3 cp "./events.json" "s3://sciety-data-extractions/events.json"

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
	$(MAKE) update-db-dump
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

.convert-cloudwatch-logs-to-jsonl:
	./scripts/convert-cloudwatch-logs-to-jsonl.sh \
		"$(CLOUDWATCH_TARGET_DIR)" \
		"$(CLOUDWATCH_JSONL_FILE)"

.generate-schema-for-cloudwatch-jsonl-file: venv
	cat "$(CLOUDWATCH_JSONL_FILE)" \
		| venv/bin/generate-schema \
		> "$(CLOUDWATCH_JSONL_SCHEMA_FILE)"

.upload-ingress-jsonl-to-bigquery:
	bq load \
		--project_id=elife-data-pipeline \
		--noreplace \
		--schema="$(CLOUDWATCH_JSONL_SCHEMA_FILE)" \
		--schema_update_option=ALLOW_FIELD_ADDITION \
		--source_format=NEWLINE_DELIMITED_JSON \
		de_proto.sciety_ingress_v1 \
		"$(CLOUDWATCH_JSONL_FILE)"

.do-upload-ingress-logs-from-cloudwatch-to-bigquery:
	$(MAKE) .cloudwatch-show-info
	$(MAKE) .export-and-download-from-cloudwatch
	$(MAKE) .convert-cloudwatch-logs-to-jsonl
	$(MAKE) .generate-schema-for-cloudwatch-jsonl-file
	$(MAKE) .upload-ingress-jsonl-to-bigquery

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
