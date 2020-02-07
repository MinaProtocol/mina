open Graphql_async
open Schema
open Signature_lib
open Unsigned

val public_key : unit -> ('a, Public_key.Compressed.t option) typ

val hardware_wallet_nonce :
  unit -> ('a, Coda_numbers.Hardware_wallet_nonce.t option) typ

val uint32 : unit -> ('a, UInt32.t option) typ

val uint64 : unit -> ('a, UInt64.t option) typ
