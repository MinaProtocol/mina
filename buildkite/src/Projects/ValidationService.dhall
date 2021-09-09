let Cmd = ../Lib/Cmds.dhall

let rootPath = "src/app/validation"
let containerImage = (../Constants/ContainerImages.dhall).elixirToolchain
let docker = Cmd.Docker::{image = containerImage}
let runCmd = \(cmd : Text) -> Cmd.run "(cd ${rootPath} && ${cmd})"
let runMix = \(cmd : Text) -> runCmd "mix ${cmd}"

-- TODO: support mix archive caching
let initCommands =
  [
    runMix "local.hex --force",
    runMix "local.rebar --force",
    runMix "deps.get"
  ]

in {
  rootPath = rootPath,
  containerImage = containerImage,
  docker = docker,
  runCmd = runCmd,
  runMix = runMix,
  initCommands = initCommands
}
