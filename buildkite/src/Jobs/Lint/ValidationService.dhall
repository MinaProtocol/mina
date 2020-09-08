let Prelude = ../../External/Prelude.dhall
let Text/concatSep = Prelude.Text.concatSep
let List/map = Prelude.List.map

let S = ../../Lib/SelectFiles.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let Cmd = ../../Lib/Cmds.dhall
let Command = ../../Command/Base.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
let Size = ../../Command/Size.dhall
let Docker = ../../Command/Docker/Type.dhall
let ValidationService = ../../Projects/ValidationService.dhall

let B = ../../External/Buildkite.dhall
let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type
let B/SoftFail/ExitStatus = B.definitions/commandStep/properties/soft_fail/union/properties/exit_status/Type

let commands =
  let sigPath = "mix_cache.sig"
  let archivePath = "\"mix-cache-\\\$(sha256sum ${sigPath} | cut -d\" \" -f1).tar.gz\""
  let unpackageScript = "tar xzf ${archivePath} -C ${ValidationService.rootPath}"

  in [
    Cmd.runInDocker ValidationService.docker "elixir --version | tail -n1 > ${sigPath}",
    Cmd.run "cat ${sigPath}",
    Cmd.cacheThrough ValidationService.docker archivePath Cmd.CacheSetupCmd::{
      package = Cmd.run "tar czf ${archivePath} -C ${ValidationService.rootPath} priv/plts",
      create =
        let scripts =
          List/map
            Cmd.Type
            Text
            (\(cmd : Cmd.Type) -> Cmd.format cmd)
            ValidationService.initCommands
        in
        Cmd.run
          (Text/concatSep " && "
            (scripts # [ "mix check --force" ]))
    },
    Cmd.runInDocker ValidationService.docker (
       unpackageScript ++ 
         " && echo \"TODO do whatever with the cached assets\""
    )
  ]

in Pipeline.build Pipeline.Config::{
  spec =
    let dirtyDhallDir = S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/ValidationService")

    in JobSpec::{
      dirtyWhen = [
        dirtyDhallDir,
        S.strictlyStart (S.contains ValidationService.rootPath)
      ],
      path = "Lint",
      name = "ValidationService"
    },
  steps = [
    Command.build Command.Config::{
      commands = commands,
      label = "Validation service lint steps; employs various forms static analysis on the elixir codebase",
      key = "lint",
      target = Size.Small,
      soft_fail = Some (
          B/SoftFail.ListSoft_fail/Type [{ exit_status = Some (B/SoftFail/ExitStatus.Number 1) }]
        ),
      docker = None Docker.Type
    }
  ]
}
