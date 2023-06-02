open Core_kernel
open Mina_base

type ('ledger, 'location) initial
type ('ledger, 'location) with_account
type ('ledger, 'location) account_updated

val init_with_signed_command :
  ledger_ops:(module Ledger_intf.S with type t = 'ledger and type location = 'location) ->
  ledger:'ledger ->
  global_slot:Mina_numbers.Global_slot.t ->
  Signed_command.t ->
  [> `FP_initial of ('ledger, 'location) initial ] Or_error.t

val find_account :
  [< `FP_initial of ('ledger, 'location) initial ] ->
  [> `FP_account_found of ('ledger, 'location) with_account ] Or_error.t

val validate_payment :
  [< `FP_account_found of ('ledger, 'location) with_account ] ->
  [> `FP_account_updated of ('ledger, 'location) account_updated ] Or_error.t

val apply :
  [< `FP_account_updated of ('ledger, 'location) account_updated ] ->
  [> `FP_halted of 'location * Account.t ]
