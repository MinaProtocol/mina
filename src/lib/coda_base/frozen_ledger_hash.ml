open Core_kernel
open Import
open Snark_params
open Snarky
open Tick
include Ledger_hash

let of_ledger_hash (h : Ledger_hash.t) : t = h
