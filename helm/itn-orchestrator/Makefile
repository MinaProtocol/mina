name        	:=      $(shell yq '.name' Chart.yaml)
version     	:=      $(shell yq '.version' Chart.yaml)
changes         :=      $(shell yq '.annotations."artifacthub.io/changes"' Chart.yaml)
changelog       ?=      CHANGELOG.md

lint: 
	helm lint . --debug --strict

dry-run:
	helm install $(name)-dry-run . --dry-run --namespace test

.SILENT:
changelog:
	touch $(changelog); echo -e "$(version):\n------" >> $(changelog) && echo -e $(changes) >> $(changelog)
