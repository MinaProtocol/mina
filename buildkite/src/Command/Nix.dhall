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
          [ Mina.fixPermissionsCommand ]
        # [ Cmd.runInDocker
              Cmd.Docker::{ image = Images.nix, extraEnv = environment, privileged = True }
              innerScript
          ]

let nixBuild
    : Text -> List Cmd.Type
    = \(attr : Text) ->
        runWithNix
          ([] : List Text)
          ("nix build --sandbox --extra-experimental-features nix-command --extra-experimental-features flakes --accept-flake-config -L \"git+file://\$(pwd)?submodules=1#${attr}\"")

in  { runWithNix = runWithNix, nixBuild = nixBuild }
