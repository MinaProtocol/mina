open Core

type t = Sexp | Json | Binary

type 'a content =
  | Block : Mina_block.t content
  | Precomputed : Mina_block.Precomputed.t content

let append_newline s = s ^ "\n"

let block_of_breadcrumb ?with_parent_statehash breadcrumb =
  let open Mina_block in
  let block = Frontier_base.Breadcrumb.block breadcrumb in
  match with_parent_statehash with
    | None ->
       block
    | Some hash ->
       let previous_state_hash = Mina_base.State_hash.of_base58_check_exn hash in
       let h = header block in
       let state = Header.protocol_state h in
       let header =
         Header.create
           ~protocol_state:{ state with previous_state_hash }
           ~protocol_state_proof:(Header.protocol_state_proof h)
           ~delta_block_chain_proof:(Header.delta_block_chain_proof h)
           ?proposed_protocol_version_opt:(Header.proposed_protocol_version_opt h)
           ~current_protocol_version:(Header.current_protocol_version h)
           ()
       in
       Mina_block.create ~header ~body:(body block)

module type S = sig
  type t

  val name : string
  val of_breadcrumb : ?with_parent_statehash:string -> Frontier_base.Breadcrumb.t -> t

  val to_string : t -> string
  val of_string : string -> t
end

module Sexp_block : S  with type t = Mina_block.t = struct
  type t = Mina_block.t

  let name = "sexp"

  let of_breadcrumb = block_of_breadcrumb


  let to_string b =
    Mina_block.sexp_of_t b
    |> Sexp.to_string
    |> append_newline

  let of_string s =
    Sexp.of_string s
    |> Mina_block.t_of_sexp
end


module Binary_block : S with type t = Mina_block.t = struct
  type t = Mina_block.t

  let name = "binary"

  let of_breadcrumb = block_of_breadcrumb

  let to_string = Binable.to_string (module Mina_block.Stable.Latest)

  let of_string = Binable.of_string (module Mina_block.Stable.Latest)
end

let () =
  let open Core_kernel in
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let logger = Logger.create ()

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let constraint_constants = precomputed_values.constraint_constants

let precomputed_of_breadcrumb ?with_parent_statehash breadcrumb =
  let open Frontier_base in
  let block = block_of_breadcrumb ?with_parent_statehash breadcrumb in
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
    |> append_newline

  let of_string s =
    Sexp.of_string s
    |> Mina_block.Precomputed.t_of_sexp
end

module Json_precomputed : S  with type t = Mina_block.Precomputed.t = struct
  type t = Mina_block.Precomputed.t

  let name = "json"

  let of_breadcrumb = precomputed_of_breadcrumb

  let to_string b =
    Mina_block.Precomputed.to_yojson b
    |> Yojson.Safe.to_string
    |> append_newline

  let of_string s =
    Yojson.Safe.from_string s
    |> Mina_block.Precomputed.of_yojson
    |> Result.ok_or_failwith
end

module Binary_precomputed : S with type t = Mina_block.Precomputed.t = struct
  type t = Mina_block.Precomputed.t

  let name = "binary"

  let of_breadcrumb = precomputed_of_breadcrumb

  let to_string =
    Binable.to_string (module Mina_block.Precomputed.Stable.Latest)

  let of_string =
    Binable.of_string (module Mina_block.Precomputed.Stable.Latest)
end
