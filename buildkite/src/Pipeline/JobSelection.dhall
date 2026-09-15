-- Selection defines how pipeline selects jobs to run
--
-- Goal of the pipeline can be either quick feedback for CI changes
-- or Nightly run which supposed to be run only on stable changes.
-- Triaged - filter eligible jobs based on tags and then apply triage based on changed made in PR
-- Full - filter only eligible jobs and do not perform triage

let Selection = < Triaged | Full >

let capitalName =
          \(selection : Selection)
      ->  merge { Triaged = "Triaged", Full = "Full" } selection

let isFull =
          \(selection : Selection)
      ->  merge { Triaged = False, Full = True } selection

let show =
          \(selection : Selection)
      ->  merge { Triaged = "triaged", Full = "full" } selection

in  { Type = Selection
    , capitalName = capitalName
    , isFull = isFull
    , show = show
    }
