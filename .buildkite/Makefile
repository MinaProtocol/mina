# Builds all dhall entrypoints
check:
	dhall --file "./src/Prepare.dhall"
	dhall --file "./src/Monorepo.dhall"
	bash -c 'for f in ./src/Jobs/**/Pipeline.dhall; do dhall --file $$f; done'
