-- A DSL for manipulating commands and their execution environments
let Prelude = ../External/Prelude.dhall

let P = Prelude

let Optional/map = P.Optional.map

let Text/concatSep = P.Text.concatSep

let Text/concatMap = P.Text.concatMap

let module =
          \(environment : List Text)
      ->  let Docker =
                { Type =
                    { image : Text
                    , extraEnv : List Text
                    , privileged : Bool
                    , useBash : Bool
                    }
                , default =
                    { extraEnv = [] : List Text
                    , privileged = False
                    , useBash = True
                    }
                }

          let Cmd = { line : Text, readable : Optional Text }

          let run
              : Text -> Cmd
              = \(script : Text) -> { line = script, readable = Some script }

          let chain
              : List Text -> Cmd
              =     \(chainOfCommands : List Text)
                ->  run (Text/concatSep " && " chainOfCommands)

          let quietly
              : Text -> Cmd
              = \(script : Text) -> { line = script, readable = None Text }

          let true
              : Cmd
              = quietly "true"

          let false
              : Cmd
              = quietly "false"

          let inDocker
              : Docker.Type -> Cmd -> Cmd
              =     \(docker : Docker.Type)
                ->  \(inner : Cmd)
                ->  let envVars =
                          Text/concatMap
                            Text
                            (\(var : Text) -> " --env ${var}")
                            (docker.extraEnv # environment)

                    let outerDir
                        : Text
                        = "\\\$BUILDKITE_BUILD_CHECKOUT_PATH"

                    let sharedDir
                        : Text
                        = "/var/buildkite/shared"

                    let entrypoint
                        : Text
                        = if docker.useBash then "/bin/bash" else "/bin/sh"

                    in  { line =
                            "docker run -it --rm --entrypoint ${entrypoint} --init --volume /var/secrets:/var/secrets --volume ${sharedDir}:/shared --volume ${outerDir}:/workdir --workdir /workdir${envVars}${      if docker.privileged

                                                                                                                                                                                                                then  " --privileged"

                                                                                                                                                                                                                else  ""} ${docker.image} -c '${inner.line}'"
                        , readable =
                            Optional/map
                              Text
                              Text
                              (     \(readable : Text)
                                ->  "Docker@${docker.image} ( ${readable} )"
                              )
                              inner.readable
                        }

          let runInDocker
              : Docker.Type -> Text -> Cmd
              =     \(docker : Docker.Type)
                ->  \(script : Text)
                ->  inDocker docker (run script)

          let CacheSetupCmd =
                { Type = { create : Cmd, package : Cmd }, default = {=} }

          let format
              : Cmd -> Text
              = \(cmd : Cmd) -> cmd.line

          let cacheThrough
              : Docker.Type -> Text -> CacheSetupCmd.Type -> Cmd
              =     \(docker : Docker.Type)
                ->  \(cachePath : Text)
                ->  \(cmd : CacheSetupCmd.Type)
                ->  let missScript =
                          format cmd.create ++ " && " ++ format cmd.package

                    let missCmd = runInDocker docker missScript

                    in  { line =
                            "./buildkite/scripts/cache-through.sh ${cachePath} \"${format
                                                                                     missCmd}\""
                        , readable =
                            Optional/map
                              Text
                              Text
                              (     \(readable : Text)
                                ->  "Cache@${cachePath} ( onMiss = ${readable} )"
                              )
                              missCmd.readable
                        }

          in  { Type = Cmd
              , Docker = Docker
              , CacheSetupCmd = CacheSetupCmd
              , quietly = quietly
              , run = run
              , chain = chain
              , true = true
              , false = false
              , runInDocker = runInDocker
              , inDocker = inDocker
              , cacheThrough = cacheThrough
              , format = format
              }

let tests =
      let M = module [ "TEST" ]

      let dockerExample =
              assert
            :     { line =
                      "docker run -it --rm --entrypoint /bin/bash --init --volume /var/secrets:/var/secrets --volume /var/buildkite/shared:/shared --volume \\\$BUILDKITE_BUILD_CHECKOUT_PATH:/workdir --workdir /workdir --env ENV1 --env ENV2 --env TEST foo/bar:tag -c 'echo hello'"
                  , readable = Some "Docker@foo/bar:tag ( echo hello )"
                  }
              ===  M.inDocker
                     M.Docker::{
                     , image = "foo/bar:tag"
                     , extraEnv = [ "ENV1", "ENV2" ]
                     }
                     (M.run "echo hello")

      let cacheExample =
              assert
            :     "./buildkite/scripts/cache-through.sh data.tar \"docker run -it --rm --entrypoint /bin/bash --init --volume /var/secrets:/var/secrets --volume /var/buildkite/shared:/shared --volume \\\$BUILDKITE_BUILD_CHECKOUT_PATH:/workdir --workdir /workdir --env ENV1 --env ENV2 --env TEST foo/bar:tag -c 'echo hello > /tmp/data/foo.txt && tar cvf data.tar /tmp/data'\""
              ===  M.format
                     ( M.cacheThrough
                         M.Docker::{
                         , image = "foo/bar:tag"
                         , extraEnv = [ "ENV1", "ENV2" ]
                         }
                         "data.tar"
                         M.CacheSetupCmd::{
                         , create = M.run "echo hello > /tmp/data/foo.txt"
                         , package = M.run "tar cvf data.tar /tmp/data"
                         }
                     )

      in  ""

in  module ../Constants/ContainerEnvVars.dhall
