let Prelude = ../External/Prelude.dhall

let DebianRepo : Type = < Local | PackagesO1Test >

let address = \(repo : DebianRepo) ->
  merge {
    Local = "$APTLY_LISTEN",
    PackagesO1Test = "http://packages.o1test.net"
  } repo

in
{
  Type = DebianRepo
  , address = address
}
