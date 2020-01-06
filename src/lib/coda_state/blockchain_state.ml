open Core_kernel
open Coda_base
open Snark_params.Tick

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t =
        { staged_ledger_hash: 'staged_ledger_hash
        ; snarked_ledger_hash: 'snarked_ledger_hash
        ; timestamp: 'time }
      [@@deriving bin_io, sexp, fields, eq, compare, hash, yojson, version]
    end
  end]

  type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t =
        ('staged_ledger_hash, 'snarked_ledger_hash, 'time) Stable.Latest.t =
    { staged_ledger_hash: 'staged_ledger_hash
    ; snarked_ledger_hash: 'snarked_ledger_hash
    ; timestamp: 'time }
  [@@deriving sexp, fields, eq, compare, hash, yojson]
end

[%%define_locally
Poly.(staged_ledger_hash, snarked_ledger_hash, timestamp)]

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Staged_ledger_hash.Stable.V1.t
        , Frozen_ledger_hash.Stable.V1.t
        , Block_time.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, eq, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash, yojson]
end

type var =
  ( Staged_ledger_hash.var
  , Frozen_ledger_hash.var
  , Block_time.Unpacked.var )
  Poly.t

let create_value ~staged_ledger_hash ~snarked_ledger_hash ~timestamp =
  {Poly.staged_ledger_hash; snarked_ledger_hash; timestamp}

let to_hlist Poly.{staged_ledger_hash; snarked_ledger_hash; timestamp} =
  H_list.[staged_ledger_hash; snarked_ledger_hash; timestamp]

let of_hlist :
    (unit, 'lbh -> 'lh -> 'ti -> unit) H_list.t -> ('lbh, 'lh, 'ti) Poly.t =
  H_list.(
    fun [staged_ledger_hash; snarked_ledger_hash; timestamp] ->
      {staged_ledger_hash; snarked_ledger_hash; timestamp})

let data_spec =
  let open Data_spec in
  [Staged_ledger_hash.typ; Frozen_ledger_hash.typ; Block_time.Unpacked.typ]

let typ : (var, Value.t) Typ.t =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_to_input ({staged_ledger_hash; snarked_ledger_hash; timestamp} : var) =
  let open Random_oracle.Input in
  List.reduce_exn ~f:append
    [ Staged_ledger_hash.var_to_input staged_ledger_hash
    ; field (Frozen_ledger_hash.var_to_hash_packed snarked_ledger_hash)
    ; bitstring
        (Bitstring_lib.Bitstring.Lsb_first.to_list
           (Block_time.Unpacked.var_to_bits timestamp)) ]

let to_input ({staged_ledger_hash; snarked_ledger_hash; timestamp} : Value.t) =
  let open Random_oracle.Input in
  List.reduce_exn ~f:append
    [ Staged_ledger_hash.to_input staged_ledger_hash
    ; field (snarked_ledger_hash :> Field.t)
    ; bitstring (Block_time.Bits.to_bits timestamp) ]

let set_timestamp t timestamp = {t with Poly.timestamp}

let negative_one ~genesis_ledger_hash =
  Poly.
    { staged_ledger_hash= Staged_ledger_hash.genesis ~genesis_ledger_hash
    ; snarked_ledger_hash=
        Frozen_ledger_hash.of_ledger_hash genesis_ledger_hash
    ; timestamp= Block_time.of_time Time.epoch }

(* negative_one and genesis blockchain states are equivalent *)
let genesis = negative_one

type display = (string, string, string) Poly.t [@@deriving yojson]

let display Poly.{staged_ledger_hash; snarked_ledger_hash; timestamp} =
  { Poly.staged_ledger_hash=
      Visualization.display_prefix_of_string @@ Ledger_hash.to_string
      @@ Staged_ledger_hash.ledger_hash staged_ledger_hash
  ; snarked_ledger_hash=
      Visualization.display_prefix_of_string
      @@ Frozen_ledger_hash.to_string snarked_ledger_hash
  ; timestamp=
      Time.to_string_trimmed ~zone:Time.Zone.utc (Block_time.to_time timestamp)
  }
