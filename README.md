## How to run

### Software Dependencies

- `python3`
- `python3-venv` (might be included in python3)
- `kubectl`
- `docker`
- `awscli`
- `make`
- `jq`
- `bash`

### Access Requirements

No secrets are stored in this repo. Credentials live on your machine.

- AWS access to the 540790251273 account.
  Ensure the AWS credentials point to the Sciety profile, e.g. by setting `AWS_PROFILE` (if needed).
- Access to the k8s cluster: _libero-eks--franklin_
- GCloud access to `elife-data-pipeline` project


### Gcloud login

Run:
```
make gcloud-login
```
Follow the prompt to open the browser and authenticate.
This stores authentication into a docker volume, pruning of volumes might affect this.

### Update Data Studio

The export might take a few minutes.


```bash
make update-datastudio
```

[Prototype dashboard](https://datastudio.google.com/reporting/bc7fa747-9d10-4272-836d-f40425b93c95) using this data.
