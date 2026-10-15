-- Memory gates: checks that a database session does not keep preparing
-- statements (see buildkite/scripts/bench/memory-gate.sh). A failed gate exits
-- with `exitStatus`, and no other failure in these jobs uses that status. A job
-- that sets `softFail` reports a failed gate without failing, while every other
-- failure of the job still fails it.

let B = ../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let B/ExitStatus =
      B.definitions/commandStep/properties/soft_fail/union/properties/exit_status/Type

let exitStatus = 42

let softFail
    : B/SoftFail
    = B/SoftFail.ListSoft_fail/Type
        [ { exit_status = Some (B/ExitStatus.Number exitStatus) } ]

in  { exitStatus = exitStatus, softFail = softFail }
