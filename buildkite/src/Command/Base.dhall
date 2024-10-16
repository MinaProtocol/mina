-- Commands are the individual command steps that CI runs

let Prelude = ../External/Prelude.dhall

let B = ../External/Buildkite.dhall

let Map = Prelude.Map

let List/map = Prelude.List.map

let List/concat = Prelude.List.concat

let Optional/map = Prelude.Optional.map

let Optional/toList = Prelude.Optional.toList

let B/Plugins/Partial = B.definitions/commandStep/properties/plugins/Type

let B/ExitStatus = B.definitions/automaticRetry/properties/exit_status/Type

let B/AutoRetryChunk = B.definitions/automaticRetry/Type.Type

let B/Retry =
      B.definitions/commandStep/properties/retry/properties/automatic/Type

let B/Manual = B.definitions/commandStep/properties/retry/properties/manual/Type

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let B/Skip = B.definitions/commandStep/properties/skip/Type

let B/If = B.definitions/commandStep/properties/if/Type

let Cmd = ../Lib/Cmds.dhall

let Decorate = ../Lib/Decorate.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

let Docker = ./Docker/Type.dhall

let DockerLogin = ./DockerLogin/Type.dhall

let Summon = ./Summon/Type.dhall

let Size = ./Size.dhall

let Plugins =
      < Docker : Docker.Type
      | DockerLogin : DockerLogin.Type
      | Summon : Summon.Type
      >

let B/Command = B.definitions/commandStep/Type Text Text Plugins Plugins

let B/Plugins = B/Plugins/Partial Plugins Plugins

let B/DependsOn =
      let OuterUnion/Type = B.definitions/dependsOn/Type

      let InnerUnion/Type = B.definitions/dependsOn/union/Type

      in  { Type = OuterUnion/Type
          , depends =
                  \(keys : List Text)
              ->  OuterUnion/Type.ListDependsOn/Type
                    ( List/map
                        Text
                        InnerUnion/Type
                        (     \(k : Text)
                          ->  InnerUnion/Type.DependsOn/Type
                                { allow_failure = Some False, step = Some k }
                        )
                        keys
                    )
          }

let B/ArtifactPaths = B.definitions/commandStep/properties/artifact_paths/Type

let TaggedKey = { Type = { name : Text, key : Text }, default = {=} }

let ExitStatus = < Code : Integer | Any >

let Retry =
      { Type = { exit_status : ExitStatus, limit : Optional Natural }
      , default.limit = None Natural
      }

let Config =
      { Type =
          { commands : List Cmd.Type
          , depends_on : List TaggedKey.Type
          , artifact_paths : List SelectFiles.Type
          , env : List TaggedKey.Type
          , label : Text
          , key : Text
          , target : Size
          , docker : Optional Docker.Type
          , docker_login : Optional DockerLogin.Type
          , summon : Optional Summon.Type
          , retries : List Retry.Type
          , flake_retry_limit : Optional Natural
          , soft_fail : Optional B/SoftFail
          , skip : Optional B/Skip
          , if : Optional B/If
          , timeout_in_minutes : Optional Integer
          }
      , default =
          { depends_on = [] : List TaggedKey.Type
          , docker = None Docker.Type
          , docker_login = None DockerLogin.Type
          , summon = None Summon.Type
          , artifact_paths = [] : List SelectFiles.Type
          , env = [] : List TaggedKey.Type
          , retries = [] : List Retry.Type
          , flake_retry_limit = Some 0
          , soft_fail = None B/SoftFail
          , skip = None B/Skip
          , if = None B/If
          , timeout_in_minutes = None Integer
          }
      }

let targetToAgent =
          \(target : Size)
      ->  merge
            { XLarge = toMap { size = "generic" }
            , Large = toMap { size = "generic" }
            , Medium = toMap { size = "generic" }
            , Small = toMap { size = "generic" }
            , Integration = toMap { size = "integration" }
            , QA = toMap { size = "qa" }
            , Hardfork = toMap { size = "hardfork" }
            , Perf = toMap { size = "perf" }
            , Multi = toMap { size = "generic-multi" }
            }
            target

let build
    : Config.Type -> B/Command.Type
    =     \(c : Config.Type)
      ->  B/Command::{
          , agents =
              let agents = targetToAgent c.target

              in        if Prelude.List.null (Map.Entry Text Text) agents

                  then  None (Map.Type Text Text)

                  else  Some agents
          , commands =
              B.definitions/commandStep/properties/commands/Type.ListString
                (Decorate.decorateAll c.commands)
          , depends_on =
              let flattened =
                    List/map
                      TaggedKey.Type
                      Text
                      (\(k : TaggedKey.Type) -> "_${k.name}-${k.key}")
                      c.depends_on

              in        if Prelude.List.null Text flattened

                  then  None B/DependsOn.Type

                  else  Some (B/DependsOn.depends flattened)
          , artifact_paths =
                    if Prelude.List.null SelectFiles.Type c.artifact_paths

              then  None B/ArtifactPaths

              else  Some
                      ( B/ArtifactPaths.String
                          (SelectFiles.compile c.artifact_paths)
                      )
          , key = Some c.key
          , label = Some c.label
          , timeout_in_minutes = c.timeout_in_minutes
          , retry = Some
              { automatic = Some
                  ( let xs
                        : List B/AutoRetryChunk
                        = List/map
                            Retry.Type
                            B/AutoRetryChunk
                            (     \(retry : Retry.Type)
                              ->  { exit_status = Some
                                      ( merge
                                          { Code =
                                                  \(i : Integer)
                                              ->  B/ExitStatus.Integer i
                                          , Any = B/ExitStatus.String "*"
                                          }
                                          retry.exit_status
                                      )
                                  , limit =
                                      Optional/map
                                        Natural
                                        Integer
                                        Natural/toInteger
                                        retry.limit
                                  }
                            )
                            (   [ Retry::{
                                  , exit_status = ExitStatus.Code -1
                                  , limit = Some 4
                                  }
                                , Retry::{
                                  , exit_status = ExitStatus.Code +255
                                  , limit = Some 4
                                  }
                                , Retry::{
                                  , exit_status = ExitStatus.Code +1
                                  , limit = c.flake_retry_limit
                                  }
                                , Retry::{
                                  , exit_status = ExitStatus.Code +100
                                  , limit = Some 4
                                  }
                                , Retry::{
                                  , exit_status = ExitStatus.Code +128
                                  , limit = Some 4
                                  }
                                , Retry::{
                                  , exit_status = ExitStatus.Code +143
                                  , limit = Some 4
                                  }
                                , Retry::{
                                  , exit_status = ExitStatus.Code +125
                                  , limit = Some 4
                                  }
                                ]
                              # c.retries
                            )

                    in  B/Retry.ListAutomaticRetry/Type xs
                  )
              , manual = Some
                  ( B/Manual.Manual/Type
                      { allowed = Some True
                      , permit_on_passed = Some True
                      , reason = None Text
                      }
                  )
              }
          , soft_fail = c.soft_fail
          , skip = c.skip
          , if = c.if
          , plugins =
              let dockerPart =
                    Optional/toList
                      (Map.Type Text Plugins)
                      ( Optional/map
                          Docker.Type
                          (Map.Type Text Plugins)
                          (     \(docker : Docker.Type)
                            ->  toMap
                                  { `docker#v3.5.0` = Plugins.Docker docker }
                          )
                          c.docker
                      )

              let dockerLoginPart =
                    Optional/toList
                      (Map.Type Text Plugins)
                      ( Optional/map
                          DockerLogin.Type
                          (Map.Type Text Plugins)
                          (     \(dockerLogin : DockerLogin.Type)
                            ->  toMap
                                  { `docker-login#v2.0.1` =
                                      Plugins.DockerLogin dockerLogin
                                  }
                          )
                          c.docker_login
                      )

              let summonPart =
                    Optional/toList
                      (Map.Type Text Plugins)
                      ( Optional/map
                          Summon.Type
                          (Map.Type Text Plugins)
                          (     \(summon : Summon.Type)
                            ->  toMap
                                  { `angaza/summon#v0.1.0` =
                                      Plugins.Summon summon
                                  }
                          )
                          c.summon
                      )

              let allPlugins =
                    List/concat
                      (Map.Entry Text Plugins)
                      (dockerPart # summonPart # dockerLoginPart)

              in        if Prelude.List.null (Map.Entry Text Plugins) allPlugins

                  then  None B/Plugins

                  else  Some (B/Plugins.Plugins/Type allPlugins)
          }

in  { Config = Config
    , build = build
    , Type = B/Command.Type
    , TaggedKey = TaggedKey
    , Retry = Retry
    , ExitStatus = ExitStatus
    }
