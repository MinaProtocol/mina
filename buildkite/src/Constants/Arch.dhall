let Arch
    : Type
    = < Amd64
      | Arm64
      >


let capitalName =
          \(artifact : Arch)
      ->  merge
            { Amd64 = "Amd64"
            , Arm64 = "Arm64"
            }
            artifact

let lowerName =
          \(artifact : Arch)
      ->  merge
            { Amd64 = "amd64"
            , Arm64 = "arm64"
            }
            artifact

let system =
          \(artifact : Arch)
      ->  merge
            { Amd64 = "x86_64"
            , Arm64 = "aarch64"
            }
            artifact

let platform =
          \(artifact : Arch)
      ->  merge
            { Amd64 = "linux/amd64"
            , Arm64 = "linux/arm64"
            }
            artifact

{
    capitalName = capitalName
  , lowerName = lowerName
  , system = system
  , platform = platform
}