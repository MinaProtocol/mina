-- The prefork release: the release the network runs before the fork. Its
-- packages (the prefork daemon and the prefork genesis ledger tool) come from
-- the legacy root of the CI cache. The packaging and the docker images read
-- this one version.

{ version = "4.0.3-73134bf" }
