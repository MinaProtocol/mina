open Core_kernel
open Coda_base
open Fold_lib
open Snark_params.Tick

module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t =
          { staged_ledger_hash: 'staged_ledger_hash
          ; snarked_ledger_hash: 'snarked_ledger_hash
          ; timestamp: 'time }
        [@@deriving bin_io, sexp, fields, eq, compare, hash, yojson, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t =
        ('staged_ledger_hash, 'snarked_ledger_hash, 'time) Stable.Latest.t =
    { staged_ledger_hash: 'staged_ledger_hash
    ; snarked_ledger_hash: 'snarked_ledger_hash
    ; timestamp: 'time }
  [@@deriving sexp, fields, eq, compare, hash, yojson]
end

let staged_ledger_hash, snarked_ledger_hash, timestamp =
  Poly.(staged_ledger_hash, snarked_ledger_hash, timestamp)

module Value = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          ( Staged_ledger_hash.Stable.V1.t
          , Frozen_ledger_hash.Stable.V1.t
          , Block_time.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving bin_io, sexp, eq, compare, hash, yojson, version]
      end

      include T
      include Module_version.Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "coda_base_blockchain_state"

      type latest = Latest.t
    end

    module Registrar = Module_version.Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
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

let var_to_triples ({staged_ledger_hash; snarked_ledger_hash; timestamp} : var)
    =
  let%map ledger_hash_triples =
    Frozen_ledger_hash.var_to_triples snarked_ledger_hash
  and staged_ledger_hash_triples =
    Staged_ledger_hash.var_to_triples staged_ledger_hash
  in
  staged_ledger_hash_triples @ ledger_hash_triples
  @ Block_time.Unpacked.var_to_triples timestamp

let fold ({staged_ledger_hash; snarked_ledger_hash; timestamp} : Value.t) =
  Fold.(
    Staged_ledger_hash.fold staged_ledger_hash
    +> Frozen_ledger_hash.fold snarked_ledger_hash
    +> Block_time.fold timestamp)

let length_in_triples =
  Staged_ledger_hash.length_in_triples + Frozen_ledger_hash.length_in_triples
  + Block_time.length_in_triples

let set_timestamp t timestamp = {t with Poly.timestamp}

let negative_one =
  lazy
    Poly.
      { staged_ledger_hash= Lazy.force Staged_ledger_hash.genesis
      ; snarked_ledger_hash=
          Frozen_ledger_hash.of_ledger_hash
          @@ Ledger.merkle_root (Lazy.force Genesis_ledger.t)
      ; timestamp= Block_time.of_time Time.epoch }

(* negative_one and genesis blockchain states are equivalent *)
let genesis = negative_one

type display = (string, string, string) Poly.t [@@deriving yojson]

let display Poly.{staged_ledger_hash; snarked_ledger_hash; timestamp} =
  { Poly.staged_ledger_hash=
      Visualization.display_short_sexp (module Ledger_hash)
      @@ Staged_ledger_hash.ledger_hash staged_ledger_hash
  ; snarked_ledger_hash=
      Visualization.display_short_sexp
        (module Frozen_ledger_hash)
        snarked_ledger_hash
  ; timestamp=
      Time.to_string_trimmed ~zone:Time.Zone.utc (Block_time.to_time timestamp)
  }
