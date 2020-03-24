open Unsigned
open Core
open Coda_base
open Snark_params.Tick
module T = Coda_numbers.Global_slot
module Length = Coda_numbers.Length

(*include (T : module type of T with module Checked := T.Checked)*)

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('slot_number, 'slots_per_epoch) t =
        {slot_number: 'slot_number; slots_per_epoch: 'slots_per_epoch}
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type ('slot_number, 'slots_per_epoch) t =
        ('slot_number, 'slots_per_epoch) Stable.Latest.t =
    {slot_number: 'slot_number; slots_per_epoch: 'slots_per_epoch}
  [@@deriving sexp, eq, compare, hash, yojson]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = (T.Stable.V1.t, Length.Stable.V1.t) Poly.Stable.V1.t
    [@@deriving sexp, eq, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

(*type 'a t_ = 'a Poly.t = {slot_number: 'a; slots_per_epoch: 'a}
[@@deriving sexp, eq, compare, hash, yojson]*)

type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash, yojson]

type value = t [@@deriving sexp, eq, compare, hash, yojson]

type var = (T.Checked.t, Length.Checked.t) Poly.t

let to_hlist ({slot_number; slots_per_epoch} : _ Poly.t) =
  H_list.[slot_number; slots_per_epoch]

let of_hlist : (unit, _) H_list.t -> _ Poly.t =
 fun H_list.[slot_number; slots_per_epoch] -> {slot_number; slots_per_epoch}

let data_spec = Data_spec.[T.Checked.typ; Length.Checked.typ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let to_input (t : value) =
  Random_oracle.Input.bitstrings
    [|T.to_bits t.slot_number; Length.to_bits t.slots_per_epoch|]

let gen =
  let open Quickcheck.Let_syntax in
  let slots_per_epoch =
    Coda_constants.compiled_constants_for_test.consensus.slots_per_epoch
    |> Length.of_int
  in
  let%map slot_number = T.gen in
  {Poly.slot_number; slots_per_epoch}

let create ~(epoch : Epoch.t) ~(slot : Slot.t) ~(slots_per_epoch : Length.t) :
    t =
  { slot_number= UInt32.Infix.(slot + (slots_per_epoch * epoch))
  ; slots_per_epoch }

let of_epoch_and_slot (epoch, slot) ~slots_per_epoch =
  create ~epoch ~slot ~slots_per_epoch

let zero ~slots_per_epoch : t = {slot_number= T.zero; slots_per_epoch}

let slot_number {Poly.slot_number; _} = slot_number

let slots_per_epoch {Poly.slots_per_epoch; _} = slots_per_epoch

let to_bits (t : t) =
  List.concat_map ~f:T.to_bits [t.slot_number; t.slots_per_epoch]

let epoch (t : t) = UInt32.Infix.(t.slot_number / t.slots_per_epoch)

let slot (t : t) = UInt32.Infix.(t.slot_number mod t.slots_per_epoch)

let to_epoch_and_slot t = (epoch t, slot t)

let ( + ) (x : t) n : t = {x with slot_number= T.add x.slot_number (T.of_int n)}

let ( < ) (t : t) (t' : t) = t.slot_number < t'.slot_number

let of_slot_number slot_number ~slots_per_epoch =
  {Poly.slot_number; slots_per_epoch}

let start_time t ~genesis_state_timestamp ~epoch_duration ~slot_duration_ms =
  let epoch, slot = to_epoch_and_slot t in
  Epoch.slot_start_time epoch slot ~genesis_state_timestamp ~epoch_duration
    ~slot_duration_ms

let end_time t ~genesis_state_timestamp ~epoch_duration ~slot_duration_ms =
  let epoch, slot = to_epoch_and_slot t in
  Epoch.slot_end_time epoch slot ~genesis_state_timestamp ~epoch_duration
    ~slot_duration_ms

let time_hum t =
  let epoch, slot = to_epoch_and_slot t in
  sprintf "epoch=%d, slot=%d" (Epoch.to_int epoch) (Slot.to_int slot)

let of_time_exn time ~(constants : Constants.t) =
  let genesis_state_timestamp = constants.genesis_state_timestamp in
  let epoch_duration = constants.epoch_duration in
  let slot_duration_ms = constants.slot_duration_ms in
  let slots_per_epoch = constants.slots_per_epoch in
  of_epoch_and_slot
    (Epoch.epoch_and_slot_of_time_exn time ~genesis_state_timestamp
       ~epoch_duration ~slot_duration_ms)
    ~slots_per_epoch

let diff (t : t) (other_epoch, other_slot) ~epoch_size =
  let open UInt32.Infix in
  let epoch, slot = to_epoch_and_slot t in
  let old_epoch =
    epoch - other_epoch - (UInt32.of_int @@ if other_slot > slot then 1 else 0)
  in
  let old_slot = (slot - other_slot) mod Length.to_uint32 epoch_size in
  of_epoch_and_slot (old_epoch, old_slot) ~slots_per_epoch:t.slots_per_epoch

module Checked = struct
  type t = var

  let ( < ) (t : t) (t' : t) = T.Checked.(t.slot_number < t'.slot_number)

  let to_bits (t : t) =
    let open Bitstring_lib.Bitstring.Lsb_first in
    let%map slot_number = T.Checked.to_bits t.slot_number
    and slots_per_epoch = Length.Checked.to_bits t.slots_per_epoch in
    List.concat_map ~f:to_list [slot_number; slots_per_epoch] |> of_list

  let to_input (var : t) =
    let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
    let%map slot_number = T.Checked.to_bits var.slot_number
    and slots_per_epoch = Length.Checked.to_bits var.slots_per_epoch in
    Random_oracle.Input.bitstrings
      (Array.map ~f:s [|slot_number; slots_per_epoch|])

  let to_epoch_and_slot (t : t) :
      (Epoch.Checked.t * Slot.Checked.t, _) Checked.t =
    make_checked (fun () ->
        let open Snarky_integer in
        let epoch, slot =
          Integer.div_mod ~m
            (T.Checked.to_integer t.slot_number)
            (Length.Checked.to_integer t.slots_per_epoch)
        in
        ( Epoch.Checked.Unsafe.of_integer epoch
        , Slot.Checked.Unsafe.of_integer slot ) )
end
