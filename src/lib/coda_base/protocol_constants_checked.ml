open Core_kernel
module T = Coda_numbers.Length
open Snark_params.Tick

(*constants actually required for blockchain snark*)
(* k
  ,c
  ,slots_per_epoch
  ,slots_per_sub_window
  ,sub_windows_per_window
  ,checkpoint_window_size_in_slots
  ,block_window_duration_ms*)

module Poly = Genesis_constants.Protocol.Poly

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (T.Stable.V1.t, T.Stable.V1.t, Block_time.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving eq, ord, hash, sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t
end

type value = Value.t

let value_of_t (t : Genesis_constants.Protocol.t) : value =
  { k= T.of_int t.k
  ; delta= T.of_int t.delta
  ; genesis_state_timestamp= Block_time.of_time t.genesis_state_timestamp }

let t_of_value (v : value) : Genesis_constants.Protocol.t =
  { k= T.to_int v.k
  ; delta= T.to_int v.delta
  ; genesis_state_timestamp= Block_time.to_time v.genesis_state_timestamp }

type var = (T.Checked.t, T.Checked.t, Block_time.Unpacked.var) Poly.t

let to_hlist ({k; delta; genesis_state_timestamp} : (_, _, _) Poly.t) =
  H_list.[k; delta; genesis_state_timestamp]

let of_hlist : (unit, 'a -> 'b -> 'c -> unit) H_list.t -> ('a, 'b, 'c) Poly.t =
 fun H_list.[k; delta; genesis_state_timestamp] ->
  {k; delta; genesis_state_timestamp}

let data_spec =
  Data_spec.[T.Checked.typ; T.Checked.typ; Block_time.Unpacked.typ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let to_input (t : value) =
  Random_oracle.Input.bitstrings
    [| T.to_bits t.k
     ; T.to_bits t.delta
     ; Block_time.Bits.to_bits t.genesis_state_timestamp |]

let var_to_input (var : var) =
  let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
  let%map k = T.Checked.to_bits var.k
  and delta = T.Checked.to_bits var.delta in
  let genesis_state_timestamp =
    Block_time.Unpacked.var_to_bits var.genesis_state_timestamp
  in
  Random_oracle.Input.bitstrings
    (Array.map ~f:s [|k; delta; genesis_state_timestamp|])
