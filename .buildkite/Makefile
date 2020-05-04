# Builds all dhall entrypoints
check:
	dhall <<< './src/Prepare.dhall'
	dhall <<< './src/Monorepo.dhall'
	for f in ./src/Jobs/**/Pipeline.dhall; do dhall --file $$f; done
