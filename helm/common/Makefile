name        	:=      $(shell yq eval '.name' Chart.yaml)
version     	:=      $(shell yq eval '.version' Chart.yaml)
changes         :=      $(shell yq eval '.annotations."artifacthub.io/changes"' Chart.yaml)
changelog       ?=      CHANGELOG.md

lint: 
	helm lint . --debug --strict

dry-run:
	helm install $(name)-dry-run . --dry-run --namespace test

.SILENT:
changelog:
	touch $(changelog); echo "\n$(version):\n------" >> $(changelog) && echo $(changes) >> $(changelog)
