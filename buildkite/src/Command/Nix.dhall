let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall

let Mina = ../Command/Mina.dhall

let S = ../Lib/SelectFiles.dhall

let r = Cmd.run

let Images = ../Constants/ContainerImages.dhall

let runWithNix
    : List Text -> Text -> List Cmd.Type
    = \(environment : List Text) ->
      \(innerScript : Text) ->
          [ Cmd.runInDocker
              Cmd.Docker::{ image = Images.nix, extraEnv = environment, privileged = True }
              ''
              mkdir -p ~/.config/nix
              printf "experimental-features = nix-command flakes\\nsandbox = true\\n" > ~/.config/nix/nix.conf
              ${innerScript}
              ''
          ]

let nixBuildAndThen
    : Text -> Text -> List Cmd.Type
    = \(attr: Text) -> \(andThen : Text) ->
        runWithNix
          ([] : List Text)
          (''
           nix shell nixpkgs#cachix -c cachix watch-exec mina-demo -- nix build -o $PWD/result --accept-flake-config -L "git+file://$PWD?submodules=1#${attr}"
           ${andThen}
           '')

let nixBuild
    : Text -> List Cmd.Type
    = \(attr : Text) -> nixBuildAndThen attr ""

in  { runWithNix = runWithNix, nixBuildAndThen = nixBuildAndThen, nixBuild = nixBuild }
