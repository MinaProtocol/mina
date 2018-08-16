open Core_kernel
open Snark_params
open Coda_numbers
module Pedersen = Tick.Pedersen

module Nonce = Nat.Make64 ()

module State_transition_data = struct
  module T = struct
    module Stable = struct
      module V1 = struct
        type ('time, 'ledger_hash, 'ledger_builder_hash) t_ =
          { time: 'time
          ; target_hash: 'ledger_hash
          ; ledger_builder_hash: 'ledger_builder_hash }
        [@@deriving bin_io, sexp]

        type t =
          ( Block_time.Stable.V1.t
          , Ledger_hash.Stable.V1.t
          , Ledger_builder_hash.Stable.V1.t )
          t_
        [@@deriving bin_io, sexp]
      end
    end

    include Stable.V1

    (* For now, the var does not track of the proof. This is due to
     how the verifier gadget is currently structured and can be changed
     once the verifier is reimplemented in snarky *)
    type var =
      (Block_time.Unpacked.var, Ledger_hash.var, Ledger_builder_hash.var) t_

    let var_to_bits {time; target_hash; ledger_builder_hash} =
      let open Tick.Let_syntax in
      let%map target_hash_bits = Ledger_hash.var_to_bits target_hash
      and ledger_builder_hash_bits =
        Ledger_builder_hash.var_to_bits ledger_builder_hash
      in
      Block_time.Unpacked.var_to_bits time
      @ target_hash_bits @ ledger_builder_hash_bits

    let fold {time; target_hash; ledger_builder_hash} =
      let open Util in
      Block_time.Bits.fold time
      +> Ledger_hash.fold target_hash
      +> Ledger_builder_hash.fold ledger_builder_hash

    let to_hlist {time; target_hash; ledger_builder_hash} =
      H_list.[time; target_hash; ledger_builder_hash]

    let of_hlist :
        (unit, 'ti -> 'th -> 'lbh -> unit) H_list.t -> ('ti, 'th, 'lbh) t_ =
     fun H_list.([time; target_hash; ledger_builder_hash]) ->
      {time; target_hash; ledger_builder_hash}

    let data_spec =
      let open Tick.Data_spec in
      [Block_time.Unpacked.typ; Ledger_hash.typ; Ledger_builder_hash.typ]

    let typ : (var, t) Tick.Typ.t =
      Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  include T

  module Signature =
    Snarky.Signature.Schnorr (Tick) (Snark_params.Tick.Signature_curve)
      (struct
        open Util
        open Tick

        type t = T.t

        type var = T.var

        let hash t ~nonce =
          let d =
            Pedersen.digest_fold Hash_prefix.signature
              (T.fold t +> List.fold nonce)
          in
          List.take (Field.unpack d) Scalar.length |> Scalar.pack

        let () = assert Insecure.signature_hash_function

        let hash_checked t ~nonce =
          let open Let_syntax in
          with_label __LOC__
            (let%bind bits = T.var_to_bits t in
             let%bind hash =
               Pedersen_hash.hash
                 ~init:
                   ( Hash_prefix.length_in_bits
                   , Signature_curve.var_of_value Hash_prefix.signature.acc )
                 (bits @ nonce)
             in
             let%map bs =
               Pedersen_hash.Digest.choose_preimage
               @@ Pedersen_hash.digest hash
             in
             List.take bs Scalar.length)
      end)
end

module Auxillary_data = struct
  module Stable = struct
    module V1 = struct
      type ('nonce, 'signature) t_ = {nonce: 'nonce; signature: 'signature}
      [@@deriving bin_io, sexp, fields]

      type t = (Nonce.Stable.V1.t, Signature.Stable.V1.t) t_
      [@@deriving bin_io, sexp]
    end
  end

  include Stable.V1

  let to_hlist {nonce; signature} = H_list.[nonce; signature]

  let of_hlist : (unit, 'n -> 's -> unit) H_list.t -> ('n, 's) t_ =
    H_list.(fun [nonce; signature] -> {nonce; signature})

  let data_spec =
    let open Tick.Data_spec in
    [Nonce.Unpacked.typ; State_transition_data.Signature.Signature.typ]

  type var =
    (Nonce.Unpacked.var, State_transition_data.Signature.Signature.var) t_

  let typ : (var, t) Tick.Typ.t =
    Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Stable = struct
  module V1 = struct
    type ('auxillary_data, 'state_transition_data) t_ =
      { auxillary_data: 'auxillary_data
      ; state_transition_data: 'state_transition_data
      ; proof: Proof.Stable.V1.t option }
    [@@deriving bin_io, sexp]

    type t = (Auxillary_data.Stable.V1.t, State_transition_data.Stable.V1.t) t_
    [@@deriving bin_io, sexp]
  end
end

include Stable.V1

(*
let hash t =
  let s = Pedersen.State.create Pedersen.params in
  Pedersen.State.update_fold s (fold_bits t) |> Pedersen.State.digest
*)

let to_hlist {auxillary_data; state_transition_data; proof= _} =
  H_list.[auxillary_data; state_transition_data]

let of_hlist : (unit, 'h -> 'b -> unit) H_list.t -> ('h, 'b) t_ =
  let open H_list in
  fun [auxillary_data; state_transition_data] ->
    {auxillary_data; state_transition_data; proof= None}

type var = (Auxillary_data.var, State_transition_data.var) t_

type value = t

let data_spec = Tick.Data_spec.[Auxillary_data.typ; State_transition_data.typ]

let typ : (var, t) Tick.Typ.t =
  Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
