let Prelude = ../External/Prelude.dhall

let Profile : Type = < Standard | Lightnet | BerkeleyMigration >

let capitalName = \(profile : Profile) ->
  merge {
    Standard = "Standard"
    , Lightnet = "Lightnet"
    , BerkeleyMigration = "BerkeleyMigration"
  } profile

let lowerName = \(profile : Profile) ->
  merge {
    Standard = "standard"
    , Lightnet = "lightnet"
    , BerkeleyMigration = "berkeley-archive-migration"
  } profile

let duneProfile = \(profile : Profile) ->
  merge {
    Standard = "devnet"
    , Lightnet = "lightnet"
    , BerkeleyMigration = "berkeley_archive_migration_devnet"
  } profile

let toSuffixUppercase = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "Lightnet"
    , BerkeleyMigration = "BerkeleyMigration"  
  } profile

let toSuffixLowercase = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "lightnet"
    , BerkeleyMigration = "berkeley-archive-migration" 
  } profile

let toLabelSegment = \(profile : Profile) ->
  merge {
    Standard = ""
    , Lightnet = "-lightnet"
    , BerkeleyMigration = "-berkeley-archive-migration" 
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
