-- Memory gates: checks that a database session does not keep preparing
-- statements (see buildkite/scripts/bench/memory-gate.sh). A failed gate exits
-- with `exitStatus`, and no other failure in these jobs uses that status. A
-- failed gate fails its job.

in  { exitStatus = 42 }
