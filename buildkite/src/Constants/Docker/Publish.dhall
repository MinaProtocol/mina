let Package = ./Package.dhall

let DockerPublish
    : Type
    = < Enabled | Disabled | Essential >

let shouldPublish =
          \(publish : DockerPublish)
      ->  \(package : Package.Type)
      ->  merge
            { Disabled = False
            , Enabled = True
            , Essential = Package.isEssential package
            }
            publish

let show =
          \(publish : DockerPublish)
      ->  merge
            { Enabled = "Enabled"
            , Disabled = "Disabled"
            , Essential = "Essential"
            }
            publish

in  { Type = DockerPublish, shouldPublish = shouldPublish, show = show }
