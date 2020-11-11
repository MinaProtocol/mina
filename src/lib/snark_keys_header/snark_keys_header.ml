open Core_kernel

(** The string that preceeds the JSON header, to identify the file kind before
    attempting to parse it.
*)
let header_string = "MINA_SNARK_KEYS\n"

module Kind = struct
  (** The 'kind' of data in the file.
    For example, a step proving key for the base transaction snark may have the
    kind:
{[
  {type_= "step_proving_key"; identifier= "transaction_snark_base"}
|}
  *)
  type t =
    { type_: string [@key "type"]
          (** Identifies the type of data that the file contains *)
    ; identifier: string
          (** Identifies the specific purpose of the file's data, in a
            human-readable format
        *)
    }
  [@@deriving yojson]
end

module Constraint_constants = struct
  module Transaction_capacity = struct
    (** Transaction pool capacity *)
    type t = Log_2 of int | Txns_per_second_x10 of int

    let to_yojson t : Yojson.Safe.t =
      match t with
      | Log_2 i ->
          `Assoc [("two_to_the", `Int i)]
      | Txns_per_second_x10 i ->
          `Assoc [("txns_per_second_x10", `Int i)]

    let of_yojson (json : Yojson.Safe.t) =
      match json with
      | `Assoc [("two_to_the", `Int i)] ->
          Ok (Log_2 i)
      | `Assoc [("txns_per_second_x10", `Int i)] ->
          Ok (Txns_per_second_x10 i)
      | `Assoc _ ->
          Error
            "Snark_keys_header.Constraint_constants.Transaction_capacity.of_yojson: \
             Expected a JSON object containing the field 'two_to_the' or \
             'txns_per_second_x10'"
      | _ ->
          Error
            "Snark_keys_header.Constraint_constants.Transaction_capacity.of_yojson: \
             Expected a JSON object"
  end

  module Fork_config = struct
    (** Fork data *)
    type t = Runtime_config.Fork_config.t =
      {previous_state_hash: string; previous_length: int}
    [@@deriving yojson]

    let opt_to_yojson t : Yojson.Safe.t =
      match t with Some t -> to_yojson t | None -> `Assoc []

    let opt_of_yojson (json : Yojson.Safe.t) =
      match json with
      | `Assoc [] ->
          Ok None
      | _ ->
          Result.map (of_yojson json) ~f:(fun t -> Some t)
  end

  (** The constants used in the constraint system.  *)
  type constraint_constants =
    { sub_windows_per_window: int
    ; ledger_depth: int
    ; work_delay: int
    ; block_window_duration_ms: int
    ; transaction_capacity: Transaction_capacity.t
    ; coinbase_amount: Unsigned_extended.Uint64.t
    ; supercharged_coinbase_factor: int
    ; account_creation_fee: Unsigned_extended.Uint64.t
    ; fork:
        (Fork_config.t option[@to_yojson Fork_config.opt_to_yojson]
                             [@of_yojson Fork_config.opt_of_yojson]) }
  [@@deriving yojson]
end

module Commits = struct
  (** Commit identifiers *)
  type t = {mina: string; marlin: string} [@@deriving yojson]
end

(** Header contents *)
type t =
  { header_version: int
  ; kind: Kind.t
  ; constraint_constants: Constraint_constants.t
  ; commits: Commits.t
  ; length: int
  ; commit_date: string
  ; constraint_system_hash: string
  ; identifying_hash: string }
[@@deriving yojson]
