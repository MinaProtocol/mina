# Builds all dhall entrypoints
check_syntax:
	# globstar doesn't work on macOS bash :facepalm:, so we can't glob
	# xargs will short-circuit if a command fails with code 255
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{}" &&  dhall --file {} > /dev/null || exit 255'

check_lint:
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{}" && dhall --ascii lint --check --inplace {} || exit 255'

check_format:
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{} format" && dhall --ascii format --check --inplace {} || exit 255'

lint:
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{}" && dhall --ascii lint --inplace {} || exit 255'

format:
	find ./src/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'echo "{}" && dhall --ascii format --inplace {} || exit 255'

check_deps:
	 $(eval TMP := $(shell mktemp -d))
	scripts/dhall/dump_dhall_to_pipelines.sh src/Jobs "$(TMP)"
	python3 scripts/dhall/checker.py --root "$(TMP)" deps

check_dirty:
	$(eval TMP := $(shell mktemp -d))
	scripts/dhall/dump_dhall_to_pipelines.sh src/Jobs "$(TMP)"
	python3 scripts/dhall/checker.py --root "$(TMP)" dirty-when  --repo "$(PWD)/../"

all: check_syntax lint format check_deps check_dirty