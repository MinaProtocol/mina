let Map =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/master/Prelude/Map/package.dhall

let Volume
    : Type
    = { name : Text, path : Text }

let PoolObject
    : Type
    = { name : Text }

let Artifacts
    : Type
    = { objects : { location : Text, paths : List Text } }

let Step =
      { Type =
          { name : Text
          , args : Optional (List Text)
          , env : Optional (List Text)
          , dir : Optional Text
          , timeout : Optional Text
          , script : Optional Text
          , entrypoint : Optional Text
          , id : Optional Text
          , secretEnv : Optional (List Text)
          , volumes : Optional (List Volume)
          }
      , default =
        { args = None (List Text)
        , env = None (List Text)
        , dir = None Text
        , timeout = None Text
        , script = None Text
        , entrypoint = None Text
        , id = None Text
        , secretEnv = None (List Text)
        , volumes = None (List Volume)
        }
      }

let Options =
      { Type =
          { env : Optional (List Text)
          , secretEnv : Optional Text
          , volumes : Optional (List Volume)
          , sourceProvenanceHash : Optional Text
          , machineType : Optional Text
          , diskSizeGb : Optional Text
          , dynamicSubstitutions : Optional Bool
          , logStreamingOption : Optional Text
          , logging : Optional Text
          , pool : Optional PoolObject
          }
      , default =
        { env = None (List Text)
        , secretEnv = None Text
        , volumes = None (List Volume)
        , sourceProvenanceHash = None Text
        , machineType = None Text
        , diskSizeGb = None Text
        , dynamicSubstitutions = None Bool
        , logStreamingOption = None Text
        , logging = None Text
        , pool = None PoolObject
        }
      }

let Cloudbuild =
      { Type =
          { steps : List Step.Type
          , timeout : Optional Text
          , queueTtl : Optional Text
          , logsBucket : Optional Text
          , options : Optional Options.Type
          , substitutions : Optional (Map.Type Text Text)
          , tags : Optional (List Text)
          , serviceAccount : Optional Text
          , artifacts : Optional Artifacts
          , images : Optional (List Text)
          }
      , default =
        { timeout = None Text
        , queueTtl = None Text
        , logsBucket = None Text
        , options = None Options.Type
        , substitutions = None (Map.Type Text Text)
        , tags = None (List Text)
        , serviceAccount = None Text
        , artifacts = None Artifacts
        , images = None (List Text)
        }
      }

in  { Volume, Artifacts, PoolObject, Step, Options, Cloudbuild }
