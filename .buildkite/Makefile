# Builds all dhall entrypoints
check:
	dhall <<< './src/Prepare.dhall'
	dhall <<< './src/Monorepo.dhall'
	ls src/jobs | xargs -I{} bash -c 'dhall <<< ./src/jobs/{}/Pipeline.dhall'
