dhall --file './src/Prepare.dhall'
{ steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export BUILDKITE_PIPELINE_MODE=PullRequest --\""
          , "echo \"--\""
          , "export BUILDKITE_PIPELINE_MODE=PullRequest"
          , "echo \"--\""
          , "echo \"-- Running: export BUILDKITE_PIPELINE_FILTER=FastOnly --\""
          , "echo \"--\""
          , "export BUILDKITE_PIPELINE_FILTER=FastOnly"
          , "echo \"--\""
          , "echo \"-- Running: ./buildkite/scripts/generate-jobs.sh > buildkite/src/gen/Jobs.dhall --\""
          , "echo \"--\""
          , "./buildkite/scripts/generate-jobs.sh > buildkite/src/gen/Jobs.dhall"
          , "dhall-to-yaml --quoted <<< '(./buildkite/src/Monorepo.dhall) { mode=(./buildkite/src/Pipeline/Mode.dhall).Type.PullRequest, filter=(./buildkite/src/Pipeline/Filter.dhall).Type.FastOnly  }' | buildkite-agent pipeline upload"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_prepare-monorepo-PullRequest-FastOnly"
    , label = Some "Prepare monorepo triage"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "codaprotocol/ci-toolchain-base:v3"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
}
dhall --file './src/Monorepo.dhall'
λ ( args
  : { filter :
        < AllTests
        | FastOnly
        | Long
        | LongAndVeryLong
        | TearDownOnly
        | ToolchainsOnly
        >
    , mode : < PullRequest | Stable >
    }
  ) →
  { steps =
    [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
      , allow_dependency_failure = None Bool
      , artifact_paths = None < ListString : List Text | String : Text >
      , branches = None < ListString : List Text | String : Text >
      , command = None < ListString : List Text | String : Text >
      , commands =
          < ListString : List Text | String : Text >.ListString
            [ "echo \"--\""
            , "echo \"-- Running: git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt --\""
            , "echo \"--\""
            , "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt"
            , "echo \"--\""
            , "echo \"-- Running: git fetch origin --\""
            , "echo \"--\""
            , "git fetch origin"
            , "echo \"--\""
            , "echo \"-- Running: ./buildkite/scripts/generate-diff.sh > _computed_diff.txt --\""
            , "echo \"--\""
            , "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
            ]
      , concurrency = None Integer
      , concurrency_group = None Text
      , depends_on =
          None
            < ListDependsOn/Type :
                List
                  < DependsOn/Type :
                      { allow_failure : Optional Bool, step : Optional Text }
                  | String : Text
                  >
            | String : Text
            >
      , env = None (List { mapKey : Text, mapValue : Text })
      , id = None Text
      , identifier = None Text
      , if = None Text
      , key = Some
          "_monorepo-triage-${merge
                                { AllTests = "AllTests"
                                , FastOnly = "FastOnly"
                                , Long = "Long"
                                , LongAndVeryLong = "LongAndVeryLong"
                                , TearDownOnly = "TearDownOnly"
                                , ToolchainsOnly = "Toolchain"
                                }
                                args.filter}-cmds-${merge
                                                      { AllTests = "AllTests"
                                                      , FastOnly = "FastOnly"
                                                      , Long = "Long"
                                                      , LongAndVeryLong =
                                                          "LongAndVeryLong"
                                                      , TearDownOnly =
                                                          "TearDownOnly"
                                                      , ToolchainsOnly =
                                                          "Toolchain"
                                                      }
                                                      args.filter}"
      , label = Some
          "Monorepo triage ${merge
                               { AllTests = "AllTests"
                               , FastOnly = "FastOnly"
                               , Long = "Long"
                               , LongAndVeryLong = "LongAndVeryLong"
                               , TearDownOnly = "TearDownOnly"
                               , ToolchainsOnly = "Toolchain"
                               }
                               args.filter}"
      , name = None Text
      , parallelism = None Integer
      , plugins = Some
          ( < ListPlugins/Type :
                List
                  ( List
                      { mapKey : Text
                      , mapValue :
                          < Docker :
                              { environment : List Text
                              , image : Text
                              , mount-buildkite-agent : Bool
                              , mount-workdir : Bool
                              , privileged : Bool
                              , propagate-environment : Bool
                              , shell : Optional (List Text)
                              }
                          | DockerLogin :
                              { password-env : Text
                              , server : Text
                              , username : Text
                              }
                          | Summon :
                              { environment : Text
                              , provider : Text
                              , secrets-file : Text
                              , substitutions : List Text
                              }
                          >
                      }
                  )
            | Plugins/Type :
                List
                  { mapKey : Text
                  , mapValue :
                      < Docker :
                          { environment : List Text
                          , image : Text
                          , mount-buildkite-agent : Bool
                          , mount-workdir : Bool
                          , privileged : Bool
                          , propagate-environment : Bool
                          , shell : Optional (List Text)
                          }
                      | DockerLogin :
                          { password-env : Text
                          , server : Text
                          , username : Text
                          }
                      | Summon :
                          { environment : Text
                          , provider : Text
                          , secrets-file : Text
                          , substitutions : List Text
                          }
                      >
                  }
            >.Plugins/Type
              [ { mapKey = "docker#v3.5.0"
                , mapValue =
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >.Docker
                      { environment =
                        [ "BUILDKITE_AGENT_ACCESS_TOKEN"
                        , "BUILDKITE_INCREMENTAL"
                        ]
                      , image = "codaprotocol/ci-toolchain-base:v3"
                      , mount-buildkite-agent = False
                      , mount-workdir = False
                      , privileged = False
                      , propagate-environment = True
                      , shell = Some [ "/bin/sh", "-e", "-c" ]
                      }
                }
              ]
          )
      , retry = Some
        { automatic = Some
            ( < AutomaticRetry/Type :
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
              | Boolean : Bool
              | ListAutomaticRetry/Type :
                  List
                    { exit_status :
                        Optional < Integer : Integer | String : Text >
                    , limit : Optional Integer
                    }
              >.ListAutomaticRetry/Type
                [ { exit_status = Some
                      (< Integer : Integer | String : Text >.Integer -1)
                  , limit = Some +4
                  }
                , { exit_status = Some
                      (< Integer : Integer | String : Text >.Integer +255)
                  , limit = Some +4
                  }
                , { exit_status = Some
                      (< Integer : Integer | String : Text >.Integer +1)
                  , limit = Some +4
                  }
                , { exit_status = Some
                      (< Integer : Integer | String : Text >.Integer +100)
                  , limit = Some +4
                  }
                , { exit_status = Some
                      (< Integer : Integer | String : Text >.Integer +128)
                  , limit = Some +4
                  }
                , { exit_status = Some
                      (< Integer : Integer | String : Text >.String "*")
                  , limit = Some +4
                  }
                ]
            )
        , manual = Some
            ( < Boolean : Bool
              | Manual/Type :
                  { allowed : Optional Bool
                  , permit_on_passed : Optional Bool
                  , reason : Optional Text
                  }
              >.Manual/Type
                { allowed = Some True
                , permit_on_passed = Some True
                , reason = None Text
                }
            )
        }
      , skip = None < Boolean : Bool | String : Text >
      , soft_fail =
          None
            < Boolean : Bool
            | ListSoft_fail/Type :
                List
                  { exit_status : Optional < Number : Natural | String : Text >
                  }
            >
      , timeout_in_minutes = None Integer
      , type = None Text
      }
    ]
  }
# globstar doesn't work on macOS bash :facepalm:, so we can't glob
# xargs will short-circuit if a command fails with code 255
find ./src/Jobs/ -name "*.dhall" -print0 | xargs -I{} -0 -n1 bash -c 'dhall --file {} || exit 255'
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( buildkite/scripts/finish-coverage-data-upload.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env COVERALLS_TOKEN --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'buildkite/scripts/finish-coverage-data-upload.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_CoverageTearDown-finish-coverage-data"
    , label = Some "Finish coverage data gathering"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = None (List < Any | Lit : Text >)
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = False
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "CoverageTearDown"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.TearDown
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: cd frontend/block-timings && yarn install && yarn build --\""
          , "echo \"--\""
          , "cd frontend/block-timings && yarn install && yarn build"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_ReasonScripts-build-block-timings"
    , label = Some "Build block-timings"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "node:14.13.1-stretch-slim"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Test/ReasonScripts" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "frontend/block-timings" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "ReasonScripts"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        (< ListString : List Text | String : Text >.String "core_dumps/*")
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( buildkite/scripts/unit-test.sh dev src/lib ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'buildkite/scripts/unit-test.sh dev src/lib'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_DaemonUnitTest-unit-test-dev"
    , label = Some "dev unit-tests"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src/lib" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "src/nonconsensus" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "Makefile" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Test/DaemonUnitTest" ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "scripts/link-coredumps" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "buildkite/scripts/unit-test" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "DaemonUnitTest"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.VeryLong
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Test
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "test_output/artifacts/*"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( bash buildkite/scripts/setup-database-for-archive-node.sh admin codarules archiver && PGPASSWORD=codarules psql -h localhost -p 5432 -U admin -d archiver -a -f src/app/archive/create_schema.sql && export PATH=\"/home/opam/.cargo/bin:\$PATH\" && eval \\\$(opam config env) && dune runtest src/app/archive ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env POSTGRES_PASSWORD=codarules --env POSTGRES_USER=admin --env POSTGRES_DB=archiver --env GO=/usr/lib/go/bin/go --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'bash buildkite/scripts/setup-database-for-archive-node.sh admin codarules archiver && PGPASSWORD=codarules psql -h localhost -p 5432 -U admin -d archiver -a -f src/app/archive/create_schema.sql && export PATH=\"/home/opam/.cargo/bin:\$PATH\" && eval \\\$(opam config env) && dune runtest src/app/archive'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_ArchiveNodeUnitTest-archive-unit-tests"
    , label = Some "Archive node unit tests"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src/lib" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "Makefile" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Test/ArchiveNodeUnitTest"
        ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "ArchiveNodeUnitTest"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Test
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@ubuntu:20.04 ( ./buildkite/scripts/connect-to-mainnet-on-compatible.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER ubuntu:20.04 /bin/sh -c './buildkite/scripts/connect-to-mainnet-on-compatible.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-daemon-mainnet-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_ConnectToMainnet-connect-to-mainnet"
    , label = Some "Connect to testnet"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit
            "buildkite/scripts/connect-to-mainnet-on-compatible"
        ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "ConnectToMainnet"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( ./buildkite/scripts/check-graphql-schema.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c './buildkite/scripts/check-graphql-schema.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBullseye-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_CheckGraphQLSchema-check-graphql-schema"
    , label = Some "Check GraphQL Schema"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/scripts/check-graphql-schema" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "Makefile" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "CheckGraphQLSchema"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: (cd src/app/validation && mix local.hex --force) --\""
          , "echo \"--\""
          , "(cd src/app/validation && mix local.hex --force)"
          , "echo \"--\""
          , "echo \"-- Running: (cd src/app/validation && mix local.rebar --force) --\""
          , "echo \"--\""
          , "(cd src/app/validation && mix local.rebar --force)"
          , "echo \"--\""
          , "echo \"-- Running: (cd src/app/validation && mix deps.get) --\""
          , "echo \"--\""
          , "(cd src/app/validation && mix deps.get)"
          , "echo \"--\""
          , "echo \"-- Running: (cd src/app/validation && mix test) --\""
          , "echo \"--\""
          , "(cd src/app/validation && mix test)"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_ValidationService-validation-service-test"
    , label = Some "Validation service tests; executes the ExUnit test suite"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "elixir:1.10-alpine"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Test/ValidationService" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "src/app/validation" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "ValidationService"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Test
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: cd buildkite && make check --\""
          , "echo \"--\""
          , "cd buildkite && make check"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_CheckDhall-check-dhall"
    , label = Some "Check all CI Dhall entrypoints"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "codaprotocol/ci-toolchain-base:v3"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/", < Any | Lit : Text >.Any ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "buildkite/Makefile" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/scripts/generate-jobs" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "CheckDhall"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Test
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@ubuntu:20.04 ( ./buildkite/scripts/replayer-test.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER ubuntu:20.04 /bin/sh -c './buildkite/scripts/replayer-test.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-archive-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_ReplayerTest-replayer-test"
    , label = Some "Replayer test"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/scripts/replayer-test" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "ReplayerTest"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4 ( cd src/app/delegation_backend && mkdir -p result && cp -R /headers result && cd src && go test ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4 /bin/sh -c 'cd src/app/delegation_backend && mkdir -p result && cp -R /headers result && cd src && go test'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_DelegationBackendUnitTest-delegation-backend-unit-tests"
    , label = Some "delegation backend unit-tests"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail = Some
        ( < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >.Boolean
            True
        )
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src/app/delegation_backend" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "Makefile" ]
      , exts = Some [ "" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit
            "buildkite/src/Jobs/Test/DelegationBackendUnitTest"
        ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "DelegationBackendUnitTest"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Test
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: chmod -R 777 src/libp2p_ipc --\""
          , "echo \"--\""
          , "chmod -R 777 src/libp2p_ipc"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( make -C src/app/libp2p_helper test ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env GO=/usr/lib/go/bin/go --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'make -C src/app/libp2p_helper test'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Libp2pUnitTest-libp2p-unit-tests"
    , label = Some "libp2p unit-tests"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: chmod -R 777 src/libp2p_ipc --\""
          , "echo \"--\""
          , "chmod -R 777 src/libp2p_ipc"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( make -C src/app/libp2p_helper test-bs-qc ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env GO=/usr/lib/go/bin/go --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'make -C src/app/libp2p_helper test-bs-qc'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Libp2pUnitTest-libp2p-bs-qc"
    , label = Some "libp2p bitswap QuickCheck"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src/app/libp2p_helper" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "src/libp2p_ipc" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "Makefile" ]
      , exts = Some [ "" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Test/Libp2pUnitTest" ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "Libp2pUnitTest"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Test
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:e4920236094ab23caad9ec9cda39babde6b777541db054e8138f71ac464f57b5 ( ./buildkite/scripts/build-test-executive.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env DUNE_PROFILE=integration_tests --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:e4920236094ab23caad9ec9cda39babde6b777541db054e8138f71ac464f57b5 /bin/sh -c './buildkite/scripts/build-test-executive.sh'"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh test_executive.exe --upload --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh test_executive.exe --upload"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh logproc.exe --upload --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh logproc.exe --upload"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some
        "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
    , key = Some "_TestnetIntegrationTests-build-test-executive"
    , label = Some "Build test-executive"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "integration" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "^.(\\.peers-reliability.test.log)\\\$"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe"
          , "echo \"--\""
          , "echo \"-- Running: MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh peers-reliability --\""
          , "echo \"--\""
          , "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh peers-reliability"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_TestnetIntegrationTests-build-test-executive"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-daemon-devnet-bullseye-docker-image"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-archive-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some
        "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
    , key = Some "_TestnetIntegrationTests-integration-test-peers-reliability"
    , label = Some "peers-reliability integration test"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "integration" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "^.(\\.chain-reliability.test.log)\\\$"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe"
          , "echo \"--\""
          , "echo \"-- Running: MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh chain-reliability --\""
          , "echo \"--\""
          , "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh chain-reliability"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_TestnetIntegrationTests-build-test-executive"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-daemon-devnet-bullseye-docker-image"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-archive-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some
        "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
    , key = Some "_TestnetIntegrationTests-integration-test-chain-reliability"
    , label = Some "chain-reliability integration test"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "integration" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "^.(\\.payment.test.log)\\\$"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe"
          , "echo \"--\""
          , "echo \"-- Running: MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh payment --\""
          , "echo \"--\""
          , "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh payment"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_TestnetIntegrationTests-build-test-executive"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-daemon-devnet-bullseye-docker-image"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-archive-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some
        "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
    , key = Some "_TestnetIntegrationTests-integration-test-payment"
    , label = Some "payment integration test"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "integration" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "^.(\\.gossip-consis.test.log)\\\$"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe"
          , "echo \"--\""
          , "echo \"-- Running: MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh gossip-consis --\""
          , "echo \"--\""
          , "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh gossip-consis"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_TestnetIntegrationTests-build-test-executive"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-daemon-devnet-bullseye-docker-image"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-archive-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some
        "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
    , key = Some "_TestnetIntegrationTests-integration-test-gossip-consis"
    , label = Some "gossip-consis integration test"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "integration" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "^.(\\.block-prod-prio.test.log)\\\$"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe"
          , "echo \"--\""
          , "echo \"-- Running: MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh block-prod-prio --\""
          , "echo \"--\""
          , "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh block-prod-prio"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_TestnetIntegrationTests-build-test-executive"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-daemon-devnet-bullseye-docker-image"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-archive-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some
        "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
    , key = Some "_TestnetIntegrationTests-integration-test-block-prod-prio"
    , label = Some "block-prod-prio integration test"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "integration" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "^.(\\.medium-bootstrap.test.log)\\\$"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe"
          , "echo \"--\""
          , "echo \"-- Running: MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh medium-bootstrap --\""
          , "echo \"--\""
          , "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh medium-bootstrap"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_TestnetIntegrationTests-build-test-executive"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-daemon-devnet-bullseye-docker-image"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-archive-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some
        "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
    , key = Some "_TestnetIntegrationTests-integration-test-medium-bootstrap"
    , label = Some "medium-bootstrap integration test"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "integration" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "^.(\\.archive-node.test.log)\\\$"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh test_executive.exe && chmod +x test_executive.exe"
          , "echo \"--\""
          , "echo \"-- Running: artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe --\""
          , "echo \"--\""
          , "artifact-cache-helper.sh logproc.exe && chmod +x logproc.exe"
          , "echo \"--\""
          , "echo \"-- Running: MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh archive-node --\""
          , "echo \"--\""
          , "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/run-test-executive.sh archive-node"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_TestnetIntegrationTests-build-test-executive"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-daemon-devnet-bullseye-docker-image"
                }
            , < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some
                    "_MinaArtifactBullseye-archive-bullseye-docker-image"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some
        "build.branch != 'develop' && build.branch != 'compatible' && build.branch != 'develop-next'"
    , key = Some "_TestnetIntegrationTests-integration-test-archive-node"
    , label = Some "archive-node integration test"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "dockerfiles" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit
            "buildkite/src/Jobs/Test/TestnetIntegrationTest"
        ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Command/TestExecutive" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "automation/terraform/modules/o1-integration"
        ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit
            "automation/terraform/modules/kubernetes/testnet"
        ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.Stable
  , name = "TestnetIntegrationTests"
  , path = "Test"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( cd src/app/trace-tool ; PATH=/home/opam/.cargo/bin:\$PATH cargo check ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'cd src/app/trace-tool ; PATH=/home/opam/.cargo/bin:\$PATH cargo check'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Rust-lint-trace-tool"
    , label = Some "Rust lint steps; trace-tool"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src/app/trace-tool" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = False
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Lint/Rust" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "Rust"
  , path = "Lint"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Lint
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: cd automation/terraform/monitoring && terraform init && terraform destroy -auto-approve --\""
          , "echo \"--\""
          , "cd automation/terraform/monitoring && terraform init && terraform destroy -auto-approve"
          , "echo \"--\""
          , "echo \"-- Running: terraform apply -auto-approve -target module.o1testnet_alerts.null_resource.alert_rules_lint -target module.o1testnet_alerts.null_resource.alert_rules_check --\""
          , "echo \"--\""
          , "terraform apply -auto-approve -target module.o1testnet_alerts.null_resource.alert_rules_lint -target module.o1testnet_alerts.null_resource.alert_rules_check"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_TestnetAlerts-lint-testnet-alerts"
    , label = Some "Lint Testnet alert rules"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit
            "automation/terraform/monitoring/o1-testnet-alerts"
        ]
      , exts = Some [ "tf" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "automation/terraform/modules/testnet-alerts"
        ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Lint/TestnetAlerts" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/TestnetAlerts" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "TestnetAlerts"
  , path = "Lint"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Lint
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: buildkite/scripts/merges-cleanly.sh compatible --\""
          , "echo \"--\""
          , "buildkite/scripts/merges-cleanly.sh compatible"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Merge-clean-merge-compatible"
    , label = Some "Check merges cleanly into compatible"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "codaprotocol/ci-toolchain-base:v3"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: buildkite/scripts/merges-cleanly.sh develop --\""
          , "echo \"--\""
          , "buildkite/scripts/merges-cleanly.sh develop"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Merge-clean-merge-develop"
    , label = Some "Check merges cleanly into develop"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "codaprotocol/ci-toolchain-base:v3"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: buildkite/scripts/merges-cleanly.sh berkeley --\""
          , "echo \"--\""
          , "buildkite/scripts/merges-cleanly.sh berkeley"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Merge-clean-merge-berkeley"
    , label = Some "Check merges cleanly into berkeley"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "codaprotocol/ci-toolchain-base:v3"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: true --\""
          , "echo \"--\""
          , "true"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Merge-pr"
    , label = Some "pr"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "codaprotocol/ci-toolchain-base:v3"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = None (List < Any | Lit : Text >)
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = False
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "Merge"
  , path = "Lint"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Lint
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: HELM_LINT=true buildkite/scripts/helm-ci.sh --\""
          , "echo \"--\""
          , "HELM_LINT=true buildkite/scripts/helm-ci.sh"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_HelmChart-lint-helm-chart"
    , label = Some "Helm chart lint steps"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "helm/" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = False
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Lint/HelmChart" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/HelmRelease" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "buildkite/scripts/helm-ci" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "HelmChart"
  , path = "Lint"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Lint
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@elixir:1.10-alpine ( elixir --version | tail -n1 > mix_cache.sig ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER elixir:1.10-alpine /bin/sh -c 'elixir --version | tail -n1 > mix_cache.sig'"
          , "echo \"--\""
          , "echo \"-- Running: cat mix_cache.sig --\""
          , "echo \"--\""
          , "cat mix_cache.sig"
          , "echo \"--\""
          , "echo \"-- Running: Cache@\"mix-cache-\\\$(sha256sum mix_cache.sig | cut -d\" \" -f1).tar.gz\" ( onMiss = Docker@elixir:1.10-alpine ( (cd src/app/validation && mix local.hex --force) && (cd src/app/validation && mix local.rebar --force) && (cd src/app/validation && mix deps.get) && mix check --force && tar czf \"mix-cache-\\\$(sha256sum mix_cache.sig | cut -d\" \" -f1).tar.gz\" -C src/app/validation priv/plts ) ) --\""
          , "echo \"--\""
          , "./buildkite/scripts/cache-through.sh \"mix-cache-\\\$(sha256sum mix_cache.sig | cut -d\" \" -f1).tar.gz\" \"docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER elixir:1.10-alpine /bin/sh -c '(cd src/app/validation && mix local.hex --force) && (cd src/app/validation && mix local.rebar --force) && (cd src/app/validation && mix deps.get) && mix check --force && tar czf \"mix-cache-\\\$(sha256sum mix_cache.sig | cut -d\" \" -f1).tar.gz\" -C src/app/validation priv/plts'\""
          , "echo \"--\""
          , "echo \"-- Running: Docker@elixir:1.10-alpine ( tar xzf \"mix-cache-\\\$(sha256sum mix_cache.sig | cut -d\" \" -f1).tar.gz\" -C src/app/validation && echo \"TODO do whatever with the cached assets\" ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER elixir:1.10-alpine /bin/sh -c 'tar xzf \"mix-cache-\\\$(sha256sum mix_cache.sig | cut -d\" \" -f1).tar.gz\" -C src/app/validation && echo \"TODO do whatever with the cached assets\"'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_ValidationService-lint"
    , label = Some
        "Validation service lint steps; employs various forms static analysis on the elixir codebase"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = Some
        ( < Boolean : Bool | String : Text >.String
            "https://github.com/MinaProtocol/mina/issues/6285"
        )
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Lint/ValidationService" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "src/app/validation" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "ValidationService"
  , path = "Lint"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Lint
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString ([] : List Text)
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Xrefcheck-xrefcheck"
    , label = Some "Verifies references in markdown"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image =
                        "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = None (List Text)
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail = Some
        ( < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >.Boolean
            True
        )
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = None (List < Any | Lit : Text >)
      , exts = Some [ "md" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit ".xrefcheck.yml" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "Xrefcheck"
  , path = "Lint"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Lint
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: ./scripts/lint_codeowners.sh --\""
          , "echo \"--\""
          , "./scripts/lint_codeowners.sh"
          , "echo \"--\""
          , "echo \"-- Running: ./scripts/lint_rfcs.sh --\""
          , "echo \"--\""
          , "./scripts/lint_rfcs.sh"
          , "echo \"--\""
          , "echo \"-- Running: make check-snarky-submodule --\""
          , "echo \"--\""
          , "make check-snarky-submodule"
          , "echo \"--\""
          , "echo \"-- Running: ./scripts/lint_preprocessor_deps.sh --\""
          , "echo \"--\""
          , "./scripts/lint_preprocessor_deps.sh"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Fast-lint"
    , label = Some
        "Fast lint steps; CODEOWNERs, RFCs, Check Snarky Submodule, Preprocessor Deps"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker#v3.5.0"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.Docker
                    { environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
                    , image = "codaprotocol/ci-toolchain-base:v3"
                    , mount-buildkite-agent = False
                    , mount-workdir = False
                    , privileged = False
                    , propagate-environment = True
                    , shell = Some [ "/bin/sh", "-e", "-c" ]
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( ./scripts/compare_ci_diff_types.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env CI=true --env BASE_BRANCH_NAME=\$BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c './scripts/compare_ci_diff_types.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Fast-lint-types"
    , label = Some "Versions compatibility linter"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( ./scripts/compare_ci_diff_binables.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env CI=true --env BASE_BRANCH_NAME=\$BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c './scripts/compare_ci_diff_binables.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_Fast-lint-binable"
    , label = Some "Binable compatibility linter"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src/" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "CODEOWNERS" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "rfcs/" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = False
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "Fast"
  , path = "Lint"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Lint
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( ./buildkite/scripts/lint-check-format.sh && ./scripts/require-ppxs.py ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c './buildkite/scripts/lint-check-format.sh && ./scripts/require-ppxs.py'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_OCaml-check"
    , label = Some "OCaml Lints; Check-format, Require-ppx-version"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Lint/OCaml" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "src/" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "OCaml"
  , path = "Lint"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Lint
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        (< ListString : List Text | String : Text >.String "updates/*")
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: HELM_RELEASE=true AUTO_DEPLOY=true buildkite/scripts/helm-ci.sh --\""
          , "echo \"--\""
          , "HELM_RELEASE=true AUTO_DEPLOY=true buildkite/scripts/helm-ci.sh"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_HelmChart-lint-helm-chart"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_HelmRelease-release-helm-chart"
    , label = Some "Helm chart release"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "Chart.yaml" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = False
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/HelmRelease" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "buildkite/scripts/helm-ci" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "HelmRelease"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Release
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "src/app/trace-tool/target/debug/trace-tool"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( cd src/app/trace-tool && PATH=/home/opam/.cargo/bin:\$PATH cargo build ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'cd src/app/trace-tool && PATH=/home/opam/.cargo/bin:\$PATH cargo build'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_TraceTool-build-trace-tool"
    , label = Some "Build trace-tool"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src/app/trace-tool" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = False
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/TraceTool" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "TraceTool"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Release
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( ./buildkite/scripts/client-sdk-tool.sh 'publish --non-interactive' ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env NPM_TOKEN --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c './buildkite/scripts/client-sdk-tool.sh 'publish --non-interactive''"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_ClientSdk-publish-client-sdk"
    , label = Some "Publish client SDK to npm"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/ClientSdk" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "frontend/client_sdk" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "src" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "ClientSdk"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "frontend/bot/*.json"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: echo export MINA_VERSION=\$(cat frontend/bot/package.json | jq '.version') > BOT_DEPLOY_ENV --\""
          , "echo \"--\""
          , "echo export MINA_VERSION=\$(cat frontend/bot/package.json | jq '.version') > BOT_DEPLOY_ENV"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_BotArtifact-setup-deploy-env"
    , label = Some "Setup o1bot docker image deploy environment"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service bot --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service bot --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_BotArtifact-bot-docker-image"
    , label = Some "Docker: bot-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/BotArtifact" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "frontend/bot" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "BotArtifact"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = Some
        ( < ListString : List Text | String : Text >.String
            "frontend/leaderboard/package.json"
        )
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: echo export MINA_VERSION=\$(cat frontend/leaderboard/package.json | jq '.version') > LEADERBOARD_DEPLOY_ENV --\""
          , "echo \"--\""
          , "echo export MINA_VERSION=\$(cat frontend/leaderboard/package.json | jq '.version') > LEADERBOARD_DEPLOY_ENV"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_LeaderboardArtifact-setup-deploy-env"
    , label = Some "Setup Leaderboard docker image deploy environment"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service leaderboard --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service leaderboard --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_LeaderboardArtifact-leaderboard-docker-image"
    , label = Some "Docker: leaderboard-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit
            "buildkite/src/Jobs/Release/LeaderboardArtifact"
        ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "frontend/leaderboard" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "LeaderboardArtifact"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Long
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Release
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: cd automation/terraform/monitoring && terraform init && terraform destroy -auto-approve --\""
          , "echo \"--\""
          , "cd automation/terraform/monitoring && terraform init && terraform destroy -auto-approve"
          , "echo \"--\""
          , "echo \"-- Running: terraform apply -auto-approve -target module.o1testnet_alerts.docker_container.sync_alert_rules --\""
          , "echo \"--\""
          , "terraform apply -auto-approve -target module.o1testnet_alerts.docker_container.sync_alert_rules"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_TestnetAlerts-lint-testnet-alerts"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = Some "build.env('DEPLOY_ALERTS') == 'true'"
    , key = Some "_TestnetAlerts-deploy-testnet-alerts"
    , label = Some "Deploy Testnet alert rules"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "automation/terraform/modules/testnet-alerts"
        ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit
            "automation/terraform/monitoring/o1-testnet-alerts"
        ]
      , exts = Some [ "tf" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/TestnetAlerts" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "TestnetAlerts"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    , < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Release
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-toolchain --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--no-cache\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-toolchain --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--no-cache\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaToolchainArtifact-toolchain-bullseye-docker-image"
    , label = Some "Docker: toolchain-bullseye-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-toolchain --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--no-cache\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-toolchain --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--no-cache\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaToolchainArtifact-toolchain-buster-docker-image"
    , label = Some "Docker: toolchain-buster-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "dockerfiles/stages/1-" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "dockerfiles/stages/2-" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "dockerfiles/stages/3-" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit
            "buildkite/src/Jobs/Release/MinaToolchainArtifact"
        ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "opam.export" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "MinaToolchainArtifact"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: chmod -R 777 src/app/libp2p_helper --\""
          , "echo \"--\""
          , "chmod -R 777 src/app/libp2p_helper"
          , "echo \"--\""
          , "echo \"-- Running: chmod -R 777 src/libp2p_ipc --\""
          , "echo \"--\""
          , "chmod -R 777 src/libp2p_ipc"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( make libp2p_helper ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env GO=/usr/lib/go/bin/go --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'make libp2p_helper'"
          , "echo \"--\""
          , "echo \"-- Running: cp src/app/libp2p_helper/result/bin/libp2p_helper . && buildkite/scripts/buildkite-artifact-helper.sh libp2p_helper --\""
          , "echo \"--\""
          , "cp src/app/libp2p_helper/result/bin/libp2p_helper . && buildkite/scripts/buildkite-artifact-helper.sh libp2p_helper"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBullseye-libp2p-helper"
    , label = Some "Build Libp2p helper for Bullseye"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( ./buildkite/scripts/build-artifact.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env DUNE_PROFILE=devnet --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env MINA_BRANCH=\$BUILDKITE_BRANCH --env MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT --env MINA_DEB_CODENAME=bullseye --env PREPROCESSOR=./scripts/zexe-standardize.sh --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c './buildkite/scripts/build-artifact.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBullseye-build-deb-pkg"
    , label = Some "Build Mina for Bullseye"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +2)
                , limit = Some +2
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBullseye-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBullseye-daemon-devnet-bullseye-docker-image"
    , label = Some "Docker: daemon-devnet-bullseye-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network mainnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network mainnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBullseye-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBullseye-daemon-mainnet-bullseye-docker-image"
    , label = Some "Docker: daemon-mainnet-bullseye-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-test-executive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-test-executive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBullseye-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBullseye-test-executive-bullseye-docker-image"
    , label = Some "Docker: test-executive-bullseye-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-archive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-archive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBullseye-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBullseye-archive-bullseye-docker-image"
    , label = Some "Docker: archive-bullseye-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-rosetta --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --no-cache\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-rosetta --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename bullseye --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --no-cache\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBullseye-rosetta-bullseye-docker-image"
    , label = Some "Docker: rosetta-bullseye-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some [ < Any | Lit : Text >.Lit "src" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "automation" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "Makefile" ]
      , exts = None (List Text)
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit
            "buildkite/scripts/connect-to-mainnet-on-compatible"
        ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Test" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Constants/DebianVersions" ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Constants/ContainerImages" ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Command/MinaArtifact" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/MinaArtifact" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "dockerfiles/stages" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "scripts/rebuild-deb" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "scripts/release-docker" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/scripts/build-artifact" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "MinaArtifactBullseye"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: chmod -R 777 src/app/libp2p_helper --\""
          , "echo \"--\""
          , "chmod -R 777 src/app/libp2p_helper"
          , "echo \"--\""
          , "echo \"-- Running: chmod -R 777 src/libp2p_ipc --\""
          , "echo \"--\""
          , "chmod -R 777 src/libp2p_ipc"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( make libp2p_helper ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env GO=/usr/lib/go/bin/go --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'make libp2p_helper'"
          , "echo \"--\""
          , "echo \"-- Running: cp src/app/libp2p_helper/result/bin/libp2p_helper . && buildkite/scripts/buildkite-artifact-helper.sh libp2p_helper --\""
          , "echo \"--\""
          , "cp src/app/libp2p_helper/result/bin/libp2p_helper . && buildkite/scripts/buildkite-artifact-helper.sh libp2p_helper"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactFocal-libp2p-helper"
    , label = Some "Build Libp2p helper for Focal"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( ./buildkite/scripts/build-artifact.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env DUNE_PROFILE=devnet --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env MINA_BRANCH=\$BUILDKITE_BRANCH --env MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT --env MINA_DEB_CODENAME=focal --env PREPROCESSOR=./scripts/zexe-standardize.sh --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c './buildkite/scripts/build-artifact.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactFocal-build-deb-pkg"
    , label = Some "Build Mina for Focal"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +2)
                , limit = Some +2
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactFocal-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactFocal-daemon-devnet-focal-docker-image"
    , label = Some "Docker: daemon-devnet-focal-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network mainnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network mainnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactFocal-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactFocal-daemon-mainnet-focal-docker-image"
    , label = Some "Docker: daemon-mainnet-focal-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-test-executive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-test-executive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactFocal-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactFocal-test-executive-focal-docker-image"
    , label = Some "Docker: test-executive-focal-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-archive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-archive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactFocal-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactFocal-archive-focal-docker-image"
    , label = Some "Docker: archive-focal-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-rosetta --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --no-cache\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=focal && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-rosetta --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename focal --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --no-cache\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactFocal-rosetta-focal-docker-image"
    , label = Some "Docker: rosetta-focal-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Constants/DebianVersions" ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Constants/ContainerImages" ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Command/MinaArtifact" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/MinaArtifact" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "dockerfiles/stages" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "scripts/rebuild-deb" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "scripts/release-docker" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/scripts/build-artifact" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "MinaArtifactFocal"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
{ pipeline.steps =
  [ { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: chmod -R 777 src/app/libp2p_helper --\""
          , "echo \"--\""
          , "chmod -R 777 src/app/libp2p_helper"
          , "echo \"--\""
          , "echo \"-- Running: chmod -R 777 src/libp2p_ipc --\""
          , "echo \"--\""
          , "chmod -R 777 src/libp2p_ipc"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:2c02933c06c5df9950cbfa936463b1eee281060bd3c921aa878684bafd0ef2db ( make libp2p_helper ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env GO=/usr/lib/go/bin/go --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:2c02933c06c5df9950cbfa936463b1eee281060bd3c921aa878684bafd0ef2db /bin/sh -c 'make libp2p_helper'"
          , "echo \"--\""
          , "echo \"-- Running: cp src/app/libp2p_helper/result/bin/libp2p_helper . && buildkite/scripts/buildkite-artifact-helper.sh libp2p_helper --\""
          , "echo \"--\""
          , "cp src/app/libp2p_helper/result/bin/libp2p_helper . && buildkite/scripts/buildkite-artifact-helper.sh libp2p_helper"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBuster-libp2p-helper"
    , label = Some "Build Libp2p helper for Buster"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b ( sudo chown -R opam . ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:ebc14d024b97b1c783c911dbef895ab0aba33fde45e420a9734f9910fe64644b /bin/sh -c 'sudo chown -R opam .'"
          , "echo \"--\""
          , "echo \"-- Running: Docker@gcr.io/o1labs-192920/mina-toolchain@sha256:2c02933c06c5df9950cbfa936463b1eee281060bd3c921aa878684bafd0ef2db ( ./buildkite/scripts/build-artifact.sh ) --\""
          , "echo \"--\""
          , "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env DUNE_PROFILE=devnet --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env MINA_BRANCH=\$BUILDKITE_BRANCH --env MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT --env MINA_DEB_CODENAME=buster --env PREPROCESSOR=./scripts/zexe-standardize.sh --env BUILDKITE_AGENT_ACCESS_TOKEN --env BUILDKITE_PIPELINE_PROVIDER --env BUILDKITE_BRANCH --env BUILDKITE_SOURCE --env BUILDKITE_PIPELINE_NAME --env BUILDKITE_AGENT_META_DATA_CLUSTER --env BUILDKITE_SCRIPT_PATH --env BUILDKITE_LABEL --env BUILDKITE_REPO --env BUILDKITE_REBUILT_FROM_BUILD_NUMBER --env BUILDKITE_PULL_REQUEST_BASE_BRANCH --env BUILDKITE_REBUILT_FROM_BUILD_ID --env BUILDKITE_TAG --env BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER --env BUILDKITE_PIPELINE_ID --env BUILDKITE_MESSAGE --env BUILDKITE_BUILD_NUMBER --env BUILDKITE_TRIGGERED_FROM_BUILD_ID --env BUILDKITE_PLUGINS --env BUILDKITE_COMMIT --env BUILDKITE_STEP_KEY --env BUILDKITE_STEP_ID --env BUILDKITE_PULL_REQUEST_REPO --env BUILDKITE_AGENT_META_DATA_SIZE --env BUILDKITE_PROJECT_PROVIDER --env BUILDKITE_ORGANIZATION_SLUG --env BUILDKITE_AGENT_ID --env BUILDKITE_BUILD_AUTHOR --env BUILDKITE_PULL_REQUEST --env BUILDKITE_BUILD_CREATOR --env BUILDKITE_COMMAND --env BUILDKITE_PIPELINE_SLUG --env BUILDKITE --env BUILDKITE_RETRY_COUNT --env BUILDKITE_PIPELINE_DEFAULT_BRANCH --env BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG --env BUILDKITE_BUILD_ID --env BUILDKITE_BUILD_URL --env BUILDKITE_AGENT_NAME --env BUILDKITE_BUILD_CREATOR_EMAIL --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_AUTHOR_EMAIL --env BUILDKITE_ARTIFACT_PATHS --env BUILDKITE_PROJECT_SLUG --env BUILDKITE_AGENT_META_DATA_QUEUE --env BUILDKITE_TIMEOUT --env BUILDKITE_STEP_IDENTIFIER gcr.io/o1labs-192920/mina-toolchain@sha256:2c02933c06c5df9950cbfa936463b1eee281060bd3c921aa878684bafd0ef2db /bin/sh -c './buildkite/scripts/build-artifact.sh'"
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBuster-build-deb-pkg"
    , label = Some "Build Mina for Buster"
    , name = None Text
    , parallelism = None Integer
    , plugins =
        None
          < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +2)
                , limit = Some +2
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBuster-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBuster-daemon-devnet-buster-docker-image"
    , label = Some "Docker: daemon-devnet-buster-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network mainnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-daemon --version \\\${MINA_DOCKER_TAG} --network mainnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBuster-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBuster-daemon-mainnet-buster-docker-image"
    , label = Some "Docker: daemon-mainnet-buster-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-test-executive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-test-executive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBuster-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBuster-test-executive-buster-docker-image"
    , label = Some "Docker: test-executive-buster-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-archive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-archive --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on = Some
        ( < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >.ListDependsOn/Type
            [ < DependsOn/Type :
                  { allow_failure : Optional Bool, step : Optional Text }
              | String : Text
              >.DependsOn/Type
                { allow_failure = None Bool
                , step = Some "_MinaArtifactBuster-build-deb-pkg"
                }
            ]
        )
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBuster-archive-buster-docker-image"
    , label = Some "Docker: archive-buster-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  , { agents = Some [ { mapKey = "size", mapValue = "generic" } ]
    , allow_dependency_failure = None Bool
    , artifact_paths = None < ListString : List Text | String : Text >
    , branches = None < ListString : List Text | String : Text >
    , command = None < ListString : List Text | String : Text >
    , commands =
        < ListString : List Text | String : Text >.ListString
          [ "echo \"--\""
          , "echo \"-- Running: export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-rosetta --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --no-cache\\\" --\""
          , "echo \"--\""
          , "export MINA_DEB_CODENAME=buster && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh --service mina-rosetta --version \\\${MINA_DOCKER_TAG} --network devnet --branch \\\${BUILDKITE_BRANCH} --deb-codename buster --deb-release \\\${MINA_DEB_RELEASE} --deb-version \\\${MINA_DEB_VERSION} --extra-args \\\"--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --no-cache\\\""
          ]
    , concurrency = None Integer
    , concurrency_group = None Text
    , depends_on =
        None
          < ListDependsOn/Type :
              List
                < DependsOn/Type :
                    { allow_failure : Optional Bool, step : Optional Text }
                | String : Text
                >
          | String : Text
          >
    , env = None (List { mapKey : Text, mapValue : Text })
    , id = None Text
    , identifier = None Text
    , if = None Text
    , key = Some "_MinaArtifactBuster-rosetta-buster-docker-image"
    , label = Some "Docker: rosetta-buster-docker-image"
    , name = None Text
    , parallelism = None Integer
    , plugins = Some
        ( < ListPlugins/Type :
              List
                ( List
                    { mapKey : Text
                    , mapValue :
                        < Docker :
                            { environment : List Text
                            , image : Text
                            , mount-buildkite-agent : Bool
                            , mount-workdir : Bool
                            , privileged : Bool
                            , propagate-environment : Bool
                            , shell : Optional (List Text)
                            }
                        | DockerLogin :
                            { password-env : Text
                            , server : Text
                            , username : Text
                            }
                        | Summon :
                            { environment : Text
                            , provider : Text
                            , secrets-file : Text
                            , substitutions : List Text
                            }
                        >
                    }
                )
          | Plugins/Type :
              List
                { mapKey : Text
                , mapValue :
                    < Docker :
                        { environment : List Text
                        , image : Text
                        , mount-buildkite-agent : Bool
                        , mount-workdir : Bool
                        , privileged : Bool
                        , propagate-environment : Bool
                        , shell : Optional (List Text)
                        }
                    | DockerLogin :
                        { password-env : Text, server : Text, username : Text }
                    | Summon :
                        { environment : Text
                        , provider : Text
                        , secrets-file : Text
                        , substitutions : List Text
                        }
                    >
                }
          >.Plugins/Type
            [ { mapKey = "docker-login#v2.0.1"
              , mapValue =
                  < Docker :
                      { environment : List Text
                      , image : Text
                      , mount-buildkite-agent : Bool
                      , mount-workdir : Bool
                      , privileged : Bool
                      , propagate-environment : Bool
                      , shell : Optional (List Text)
                      }
                  | DockerLogin :
                      { password-env : Text, server : Text, username : Text }
                  | Summon :
                      { environment : Text
                      , provider : Text
                      , secrets-file : Text
                      , substitutions : List Text
                      }
                  >.DockerLogin
                    { password-env = "DOCKER_PASSWORD"
                    , server = ""
                    , username = "o1botdockerhub"
                    }
              }
            ]
        )
    , retry = Some
      { automatic = Some
          ( < AutomaticRetry/Type :
                { exit_status : Optional < Integer : Integer | String : Text >
                , limit : Optional Integer
                }
            | Boolean : Bool
            | ListAutomaticRetry/Type :
                List
                  { exit_status : Optional < Integer : Integer | String : Text >
                  , limit : Optional Integer
                  }
            >.ListAutomaticRetry/Type
              [ { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer -1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +255)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +1)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +100)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.Integer +128)
                , limit = Some +4
                }
              , { exit_status = Some
                    (< Integer : Integer | String : Text >.String "*")
                , limit = Some +4
                }
              ]
          )
      , manual = Some
          ( < Boolean : Bool
            | Manual/Type :
                { allowed : Optional Bool
                , permit_on_passed : Optional Bool
                , reason : Optional Text
                }
            >.Manual/Type
              { allowed = Some True
              , permit_on_passed = Some True
              , reason = None Text
              }
          )
      }
    , skip = None < Boolean : Bool | String : Text >
    , soft_fail =
        None
          < Boolean : Bool
          | ListSoft_fail/Type :
              List
                { exit_status : Optional < Number : Natural | String : Text > }
          >
    , timeout_in_minutes = None Integer
    , type = None Text
    }
  ]
, spec =
  { dirtyWhen =
    [ { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Constants/DebianVersions" ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Constants/ContainerImages" ]
      , exts = Some [ "dhall" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Command/MinaArtifact" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/src/Jobs/Release/MinaArtifact" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "dockerfiles/stages" ]
      , exts = None (List Text)
      , strictEnd = False
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "scripts/rebuild-deb" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some [ < Any | Lit : Text >.Lit "scripts/release-docker" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    , { dir = Some
        [ < Any | Lit : Text >.Lit "buildkite/scripts/build-artifact" ]
      , exts = Some [ "sh" ]
      , strictEnd = True
      , strictStart = True
      }
    ]
  , mode = < PullRequest | Stable >.PullRequest
  , name = "MinaArtifactBuster"
  , path = "Release"
  , tags =
    [ < Fast
      | Lint
      | Long
      | Release
      | TearDown
      | Test
      | Toolchain
      | VeryLong
      >.Fast
    ]
  }
}
