# Builds all dhall entrypoints
check:
	dhall --file './src/Prepare.dhall'
	dhall --file './src/Monorepo.dhall'
	# globstar doesn't work on macOS bash :facepalm:, so we can't glob
	# xargs will short-circuit if a command fails with code 255
	find ./src/Jobs/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'dhall --file {} || exit 255'
