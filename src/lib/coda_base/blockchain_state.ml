open Core_kernel
open Snark_params
open Tick
open Fold_lib
open Bitstring_lib
open Tuple_lib

module type S = sig
  type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t_ =
    { staged_ledger_hash: 'staged_ledger_hash
    ; snarked_ledger_hash: 'snarked_ledger_hash
    ; timestamp: 'time }
  [@@deriving sexp, eq, compare, fields, yojson]

  module Value : sig
    module Stable : sig
      module V1 : sig
        type t =
          ( Staged_ledger_hash.Stable.V1.t
          , Frozen_ledger_hash.Stable.V1.t
          , Block_time.Stable.V1.t )
          t_
        [@@deriving bin_io, sexp, eq, compare, hash, yojson]
      end

      module Latest : module type of V1
    end

    type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash, yojson]
  end

  include
    Snarkable.S
    with type var =
                ( Staged_ledger_hash.var
                , Frozen_ledger_hash.var
                , Block_time.Unpacked.var )
                t_
     and type value := Value.t

  val create_value :
       staged_ledger_hash:Staged_ledger_hash.t
    -> snarked_ledger_hash:Frozen_ledger_hash.t
    -> timestamp:Block_time.t
    -> Value.t

  val length_in_triples : int

  val genesis : Value.t

  val set_timestamp : ('a, 'b, 'c) t_ -> 'c -> ('a, 'b, 'c) t_

  val fold : Value.t -> bool Triple.t Fold.t

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  type display = (string, string, string) t_ [@@deriving yojson]

  val display : Value.t -> display

  module Message :
    Signature_lib.Checked.Message_intf
    with type ('a, 'b) checked := ('a, 'b) Tick.Checked.t
     and type boolean_var := Tick.Boolean.var
     and type curve_scalar := Inner_curve.Scalar.t
     and type curve_scalar_var := Inner_curve.Scalar.var
     and type t = Value.t
     and type var = var

  module Signature :
    Signature_lib.Checked.S
    with type ('a, 'b) typ := ('a, 'b) Tick.Typ.t
     and type ('a, 'b) checked := ('a, 'b) Tick.Checked.t
     and type boolean_var := Tick.Boolean.var
     and type curve := Snark_params.Tick.Inner_curve.t
     and type curve_var := Snark_params.Tick.Inner_curve.var
     and type curve_scalar := Snark_params.Tick.Inner_curve.Scalar.t
     and type curve_scalar_var := Snark_params.Tick.Inner_curve.Scalar.var
     and module Message := Message
     and module Shifted := Snark_params.Tick.Inner_curve.Checked.Shifted
end

module Make (Genesis_ledger : sig
  val t : Ledger.t
end) : S = struct
  type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t_ =
    { staged_ledger_hash: 'staged_ledger_hash
    ; snarked_ledger_hash: 'snarked_ledger_hash
    ; timestamp: 'time }
  [@@deriving bin_io, sexp, fields, eq, compare, hash, yojson]

  module Value = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          let version = 1

          type t =
            ( Staged_ledger_hash.Stable.V1.t
            , Frozen_ledger_hash.Stable.V1.t
            , Block_time.Stable.V1.t )
            t_
          [@@deriving bin_io, sexp, eq, compare, hash, yojson]
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
    t_

  let create_value ~staged_ledger_hash ~snarked_ledger_hash ~timestamp =
    {staged_ledger_hash; snarked_ledger_hash; timestamp}

  let to_hlist {staged_ledger_hash; snarked_ledger_hash; timestamp} =
    H_list.[staged_ledger_hash; snarked_ledger_hash; timestamp]

  let of_hlist :
      (unit, 'lbh -> 'lh -> 'ti -> unit) H_list.t -> ('lbh, 'lh, 'ti) t_ =
    H_list.(
      fun [staged_ledger_hash; snarked_ledger_hash; timestamp] ->
        {staged_ledger_hash; snarked_ledger_hash; timestamp})

  let data_spec =
    let open Data_spec in
    [Staged_ledger_hash.typ; Frozen_ledger_hash.typ; Block_time.Unpacked.typ]

  let typ : (var, Value.t) Typ.t =
    Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_triples
      ({staged_ledger_hash; snarked_ledger_hash; timestamp} : var) =
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

  let set_timestamp t timestamp = {t with timestamp}

  let genesis =
    { staged_ledger_hash= Staged_ledger_hash.dummy
    ; snarked_ledger_hash=
        Frozen_ledger_hash.of_ledger_hash
        @@ Ledger.merkle_root Genesis_ledger.t
    ; timestamp= Genesis_state_timestamp.value |> Block_time.of_time }

  type display = (string, string, string) t_ [@@deriving yojson]

  let display {staged_ledger_hash; snarked_ledger_hash; timestamp} =
    { staged_ledger_hash=
        Visualization.display_short_sexp (module Ledger_hash)
        @@ Staged_ledger_hash.ledger_hash staged_ledger_hash
    ; snarked_ledger_hash=
        Visualization.display_short_sexp
          (module Frozen_ledger_hash)
          snarked_ledger_hash
    ; timestamp=
        Time.to_string_trimmed ~zone:Time.Zone.utc
          (Block_time.to_time timestamp) }

  module Message = struct
    open Tick

    type t = Value.t

    type nonrec var = var

    let hash t ~nonce =
      let d =
        Pedersen.digest_fold Hash_prefix.signature
          Fold.(fold t +> Fold.(group3 ~default:false (of_list nonce)))
      in
      List.take (Field.unpack d) Inner_curve.Scalar.length_in_bits
      |> Inner_curve.Scalar.of_bits

    let () = assert Insecure.signature_hash_function

    let%snarkydef hash_checked t ~nonce =
      let%bind trips = var_to_triples t in
      let%bind hash =
        Pedersen.Checked.digest_triples ~init:Hash_prefix.signature
          ( trips
          @ Fold.(to_list (group3 ~default:Boolean.false_ (of_list nonce))) )
      in
      let%map bs = Pedersen.Checked.Digest.choose_preimage hash in
      Bitstring.Lsb_first.of_list
        (List.take (bs :> Boolean.var list) Inner_curve.Scalar.length_in_bits)
  end

  module Signature =
    Signature_lib.Checked.Schnorr (Tick) (Snark_params.Tick.Inner_curve)
      (Message)
end
