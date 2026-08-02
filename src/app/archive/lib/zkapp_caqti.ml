(* zkapp_caqti.ml -- Caqti helpers for zkApp Set_or_keep / Or_ignore fields

   These live here rather than in Mina_caqti so that Mina_caqti stays free of
   Mina_base. Mina_caqti is a generic helper library over the Caqti bindings;
   depending on Mina_base for two variant types pulled the whole protocol
   stack into every tool that talks to the archive database. *)

open Async
open Core_kernel
open Mina_base

(* if zkApp-related item is Set, run `f` *)
let add_if_zkapp_set (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg Zkapp_basic.Set_or_keep.t -> ('res option, 'err) Deferred.Result.t =
  Fn.compose (Mina_caqti.add_if_some f) Zkapp_basic.Set_or_keep.to_option

(* if zkApp-related item is Check, run `f` *)
let add_if_zkapp_check (f : 'arg -> ('res, 'err) Deferred.Result.t) :
    'arg Zkapp_basic.Or_ignore.t -> ('res option, 'err) Deferred.Result.t =
  Fn.compose (Mina_caqti.add_if_some f) Zkapp_basic.Or_ignore.to_option

(** convert options to Set or Keep for zkApps-related results *)
let get_zkapp_set_or_keep (item_opt : 'arg option)
    ~(f : 'arg -> ('res, _) Deferred.Result.t) :
    'res Zkapp_basic.Set_or_keep.t Deferred.t =
  Mina_caqti.make_get_opt ~of_option:Zkapp_basic.Set_or_keep.of_option ~f
    item_opt

(** convert options to Check or Ignore for zkApps-related results *)
let get_zkapp_or_ignore (item_opt : 'arg option)
    ~(f : 'arg -> ('res, _) Deferred.Result.t) :
    'res Zkapp_basic.Or_ignore.t Deferred.t =
  Mina_caqti.make_get_opt item_opt ~of_option:Zkapp_basic.Or_ignore.of_option ~f
