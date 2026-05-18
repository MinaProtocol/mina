-- defines supported branches (scopes) for the pipeline
--
-- Scope of the pipeline can be either Master, Compatible, Mesa or Develop.
-- Master - run pipeline for master branch
-- Compatible - run pipeline for compatible branch
-- Mesa - run pipeline for mesa branch
-- Develop - run pipeline for develop branch
--
-- Supported Branches are used to determine which jobs should be run in the pipeline.
-- We can see scope as specialized tag that is applied to jobs. Single job can have multiple scopes.
-- On Pipeline top level we can filter jobs based on scope, tags and mode.

let Prelude = ../External/Prelude.dhall

let Extensions = ../Lib/Extensions.dhall

let Branch = < Master | Compatible | Mesa | Develop >

let capitalName =
          \(branch : Branch)
      ->  merge
            { Master = "Master"
            , Compatible = "Compatible"
            , Mesa = "Mesa"
            , Develop = "Develop"
            }
            branch

let lowerName =
          \(branch : Branch)
      ->  merge
            { Master = "master"
            , Compatible = "compatible"
            , Mesa = "mesa"
            , Develop = "develop"
            }
            branch

let join =
          \(branches : List Branch)
      ->  Extensions.join "," (Prelude.List.map Branch Text lowerName branches)

let Full = [ Branch.Master, Branch.Compatible, Branch.Mesa, Branch.Develop ]

in  { Type = Branch
    , Full = Full
    , capitalName = capitalName
    , lowerName = lowerName
    , join = join
    }
