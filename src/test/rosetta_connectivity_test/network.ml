(* Networks the test can join, and the fixed on-chain objects the sanity checks
   look up on each. The objects are old enough to be in every archive the test
   builds, because rosetta falls back to the daemon for the recent chain and to
   the archive for everything else. *)

open Core_kernel

type t = Devnet | Mainnet

let of_string = function
  | "devnet" ->
      Devnet
  | "mainnet" ->
      Mainnet
  | s ->
      failwithf "unknown network %s (expected devnet or mainnet)" s ()

let to_string = function Devnet -> "devnet" | Mainnet -> "mainnet"

let arg_type = Command.Arg_type.create of_string

type fixtures =
  { block : string
  ; account : string
  ; payment_transaction : string
  ; zkapp_transaction : string
  }

let fixtures = function
  | Devnet ->
      { block = "3NLX177ZPMRfgYX6sX6tEnhb97gvjWKiivk9Fk2q8M6vHHjAQPYk"
      ; account = "B62qizKV19RgCtdosaEnoJRF72YjTSDyfJ5Nrdu8ygKD3q2eZcqUp7B"
      ; payment_transaction =
          "5Jumdze53X3k8rVaNQpJKdt8voGXRgVcFBZugg21FE1K7QkJBhLb"
      ; zkapp_transaction =
          "5JuJuyKtrMvxGroWyNE3sxwpuVsupvj7SA8CDX4mqWms4ZZT4Arz"
      }
  | Mainnet ->
      { block = "3NLaE5ygWrgssHjchYR7auQTZHveVV5au5cv5VhbWWYPdbdSm4FA"
      ; account = "B62qrQKS9ghd91shs73TCmBJRW9GzvTJK443DPx2YbqcyoLc56g1ny9"
      ; payment_transaction =
          "5JvGLZ22Pt5co9ikFhHVcewsrGNx9xwPx16oKvJ42oujZRU7Ymfh"
      ; zkapp_transaction =
          "5Ju42hSKHMPFFuH2iar8V1scHdWET2TV8ocaazRbEea5yFWDe7RH"
      }
