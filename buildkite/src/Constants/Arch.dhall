let Arch
    : Type
    = < Amd64 | Arm64 >

let capitalName =
      \(artifact : Arch) -> merge { Amd64 = "Amd64", Arm64 = "Arm64" } artifact

let lowerName =
      \(artifact : Arch) -> merge { Amd64 = "amd64", Arm64 = "arm64" } artifact

let system =
          \(artifact : Arch)
      ->  merge { Amd64 = "x86_64", Arm64 = "aarch64" } artifact

let labelSuffix =
      \(artifact : Arch) -> merge { Amd64 = "", Arm64 = " Arm64" } artifact

let nameSuffix =
      \(artifact : Arch) -> merge { Amd64 = "", Arm64 = "Arm64" } artifact

let toSuffixUppercase =
      \(artifact : Arch) -> merge { Amd64 = "", Arm64 = "-Arm64" } artifact

let toSuffixLowercase =
      \(artifact : Arch) -> merge { Amd64 = "", Arm64 = "-arm64" } artifact

let platform =
          \(artifact : Arch)
      ->  merge { Amd64 = "linux/amd64", Arm64 = "linux/arm64" } artifact

let toOptionalSuffixLowercase =
          \(artifact : Arch)
      ->  merge
            { Amd64 = None Text, Arm64 = Some (toSuffixLowercase artifact) }
            artifact

let toOptional =
          \(artifact : Arch)
      ->  merge
            { Amd64 = None Text, Arm64 = Some (lowerName artifact) }
            artifact

in  { Type = Arch
    , capitalName = capitalName
    , lowerName = lowerName
    , nameSuffix = nameSuffix
    , labelSuffix = labelSuffix
    , system = system
    , platform = platform
    , toSuffixUppercase = toSuffixUppercase
    , toSuffixLowercase = toSuffixLowercase
    , toOptionalSuffixLowercase = toOptionalSuffixLowercase
    , toOptional = toOptional
    }
