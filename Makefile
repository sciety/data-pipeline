AWS_DEFAULT_REGION := us-east-1

export AWS_DEFAULT_REGION


.PHONY: clean update*

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

update-datastudio: update-db-dump .bq-update-events
	./scripts/upload-ingress-logs-from-cloudwatch-to-bigquery.sh
