##@ Coverage & docs

########################################
# Coverage testing and output

.PHONY: test-coverage
test-coverage: SHELL := /bin/bash
test-coverage: libp2p_helper ## Run tests with coverage instrumentation
	scripts/create_coverage_profiles.sh

.PHONY: coverage-html
coverage-html: ## Generate HTML report from coverage data
ifeq ($(shell find _build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	bisect-ppx-report html --source-path=_build/default --coverage-path=_build/default
endif

.PHONY: coverage-summary
coverage-summary: ## Generate coverage summary report
ifeq ($(shell find _build/default -name bisect\*.out),"")
	echo "No coverage output; run make test-coverage"
else
	bisect-ppx-report summary --coverage-path=_build/default --per-file
endif

########################################
# Diagrams for documentation

%.dot.png: %.dot
	dot -Tpng $< > $@

%.tex.pdf: %.tex
	cd $(dir $@) && pdflatex -halt-on-error $(notdir $<)
	cp $(@:.tex.pdf=.pdf) $@

%.tex.png: %.tex.pdf
	convert -density 600x600 $< -quality 90 -resize 1080x1080 $@

%.conv.tex.png: %.conv.tex
	cd $(dir $@) && pdflatex -halt-on-error -shell-escape $(notdir $<)

# TODO: this, but smarter so we don't have to add every library
doc_diagram_sources=$(addprefix docs/res/,*.dot *.tex *.conv.tex)
doc_diagram_sources+=$(addprefix rfcs/res/,*.dot *.tex *.conv.tex)
doc_diagram_sources+=$(addprefix src/lib/transition_frontier/res/,*.dot *.tex *.conv.tex)

.PHONY: doc_diagrams
doc_diagrams: $(addsuffix .png,$(wildcard $(doc_diagram_sources))) ## Generate documentation diagrams

.PHONY: export_git_env_vars
export_git_env_vars: ## Export git environment variables for use in scripts
	KEEP_MY_TAGS_INTACT=true \
		./scripts/export-git-env-vars.sh

