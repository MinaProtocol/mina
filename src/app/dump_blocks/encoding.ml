open Core

module type S = sig
  type t

  val name : string
  val of_breadcrumb : Frontier_base.Breadcrumb.t -> t

  val to_string : t -> string
  val of_string : string -> t
end

module Sexp_block : S  with type t = Mina_block.t = struct
  type t = Mina_block.t

  let name = "sexp"

  let of_breadcrumb = Frontier_base.Breadcrumb.block

  let to_string b =
    Mina_block.sexp_of_t b
    |> Sexp.to_string

  let of_string s =
    Sexp.of_string s
    |> Mina_block.t_of_sexp
end

let () =
  let open Core_kernel in
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let logger = Logger.create ()

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let constraint_constants = precomputed_values.constraint_constants

let precomputed_of_breadcrumb breadcrumb =
  let open Frontier_base in
  let block = Breadcrumb.block breadcrumb in
  let staged_ledger =
    Transition_frontier.Breadcrumb.staged_ledger breadcrumb
  in
  let scheduled_time =
    Mina_block.(Header.protocol_state @@ header block)
    |> Mina_state.Protocol_state.blockchain_state
    |> Mina_state.Blockchain_state.timestamp
  in
  Mina_block.Precomputed.of_block ~logger ~constraint_constants
    ~staged_ledger ~scheduled_time
    (Breadcrumb.block_with_hash breadcrumb)

module Sexp_precomputed : S with type t = Mina_block.Precomputed.t = struct
  type t = Mina_block.Precomputed.t

  let name = "sexp"

  let of_breadcrumb = precomputed_of_breadcrumb

  let to_string b =
    Mina_block.Precomputed.sexp_of_t b
    |> Sexp.to_string

  let of_string s =
    Sexp.of_string s
    |> Mina_block.Precomputed.t_of_sexp
end

module Json_precomputed : S  with type t = Mina_block.Precomputed.t= struct
  type t = Mina_block.Precomputed.t

  let name = "json"

  let of_breadcrumb = precomputed_of_breadcrumb

  let to_string b =
    Mina_block.Precomputed.to_yojson b
    |> Yojson.Safe.to_string

  let of_string s =
    Yojson.Safe.from_string s
    |> Mina_block.Precomputed.of_yojson
    |> Result.ok_or_failwith
end
