let Prelude = ../External/Prelude.dhall

let Profile : Type = < Standard | Lightnet | BerkeleyMigration | Hardfork >

let capitalName = \(profile : Profile) ->
  merge {
    Standard = "Standard"
    , Lightnet = "Lightnet"
    , BerkeleyMigration = "BerkeleyMigration"
    , Hardfork = "Hardfork"
  } profile

let lowerName = \(profile : Profile) ->
  merge {
    Standard = "standard"
    , Lightnet = "lightnet"
    , BerkeleyMigration = "berkeley-archive-migration"
    , Hardfork = "hardfork"
  } profile

let duneProfile = \(profile : Profile) ->
  merge {
    Standard = "devnet"
    , Lightnet = "lightnet"
    , BerkeleyMigration = "berkeley_archive_migration"
    , Hardfork = "hardfork"
  } profile

let toSuffixUppercase = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "Lightnet"
    , BerkeleyMigration = "BerkeleyMigration"  
    , Hardfork = "Hardfork"
  } profile

let toSuffixLowercase = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "lightnet"
    , BerkeleyMigration = "berkeley-archive-migration" 
    , Hardfork = "hardfork"
  } profile

let toLabelSegment = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "-lightnet"
    , BerkeleyMigration = "-berkeley-archive-migration" 
    , Hardfork = "-hardfork"
  } profile



in

{
  Type = Profile
  , capitalName = capitalName
  , lowerName = lowerName
  , duneProfile = duneProfile
  , toSuffixUppercase = toSuffixUppercase
  , toSuffixLowercase = toSuffixLowercase
  , toLabelSegment = toLabelSegment
}
