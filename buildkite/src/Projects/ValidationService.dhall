let Cmd = ../Lib/Cmds.dhall

let rootPath = "src/app/validation"
let containerImage = (../Constants/ContainerImages.dhall).elixirToolchain
let runCmd = \(cmd : Text) -> Cmd.run "(cd ${rootPath}; ${cmd})"
let runMix = \(cmd : Text) -> runCmd "mix ${cmd}"

let initCommands =
  let docker = Cmd.Docker::{image = containerImage}
  let validationPath = "src/app/validation"
  let sigPath = "mix_cache.sig"
  let archivePath = "\"mix-cache-\\\$(sha256sum ${sigPath} | cut -d\" \" -f1).tar.gz\""
  in [
    Cmd.run "elixir --version | tail -n1 > ${sigPath}",
    Cmd.run "(cd ${validationPath}; mix local.hex --force)",
    Cmd.run "(cd ${validationPath}; mix local.rebar --force)",
    Cmd.run "echo \\\$(pwd)",
    Cmd.cacheThrough docker archivePath Cmd.CompoundCmd::{
      preprocess = Cmd.run "tar czf ${archivePath} -C ${validationPath} archive.ez priv/plts _build",
      postprocess = Cmd.run "tar xzf ${archivePath} -C ${validationPath}",
      inner = Cmd.run "(cd ${validationPath}; ([ ! -f archive.ex ] || mix archive.install archive.ez) && mix deps.get && mix archive.build -o archive.ez && mix dialyzer.build)"
    }
  ]

in {
  rootPath = rootPath,
  containerImage = containerImage,
  runCmd = runCmd,
  runMix = runMix,
  initCommands = initCommands
}
