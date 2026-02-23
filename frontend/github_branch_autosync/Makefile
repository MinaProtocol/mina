clean:
	find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
	find . -type f -name '*.zip' -delete

# This hack address issue on gcloud functions framework when importing local module
# in python. We need to remove leading '.' from import 
# https://github.com/GoogleCloudPlatform/functions-framework-python/pull/169
fix_comp_on_gcloud:
	sed -i 's/from .lib import /from lib import /' github_autosync/gcloud_entrypoint/main.py 

zip_package: clean fix_comp_on_gcloud
	zip -r github_autosync.zip github_autosync/gcloud_entrypoint

run-tests:
	python3 -X tracemalloc=25 -m unittest discover -t tests -s tests

deploy: zip_package check-env
	@gcloud functions deploy AutoSyncBranches \
	--project=o1labs-192920 \
	--region=us-central1 \
	--runtime=python311 \
	--source=github_autosync/gcloud_entrypoint \
	--memory=1024MB \
	--timeout=300 \
	--trigger-http \
	--allow-unauthenticated \
	--entry-point=handle_incoming_commit_push \
	--set-env-vars=WEBHOOK_APP_USER=$(WEBHOOK_APP_USER),WEBHOOK_APP_REPO=$(WEBHOOK_APP_REPO),WEBHOOK_APP_TOKEN=$(WEBHOOK_APP_TOKEN),WEBHOOK_APP_GITHUB_SECRET=$(WEBHOOK_APP_GITHUB_SECRET)

	@echo --- reverts import fixing ---
	sed -i 's/from lib import /from .lib import /' github_autosync/gcloud_entrypoint/main.py 

check-env:
# Lack of indentation is required:
# https://stackoverflow.com/questions/4728810/how-to-ensure-makefile-variable-is-set-as-a-prerequisite
ifndef WEBHOOK_APP_USER
	$(error WEBHOOK_APP_USER is undefined)
endif
ifndef WEBHOOK_APP_REPO
	$(error WEBHOOK_APP_REPO is undefined)
endif
ifndef WEBHOOK_APP_TOKEN
	$(error WEBHOOK_APP_TOKEN is undefined)
endif
ifndef WEBHOOK_APP_GITHUB_SECRET
	$(error WEBHOOK_APP_GITHUB_SECRET is undefined)
endif