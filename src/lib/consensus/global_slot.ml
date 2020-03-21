open Unsigned
open Core
open Coda_base
open Snark_params.Tick
module T = Coda_numbers.Global_slot

(*include (T : module type of T with module Checked := T.Checked)*)

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = {slot_number: 'a; slots_per_epoch: 'a}
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t = {slot_number: 'a; slots_per_epoch: 'a}
  [@@deriving sexp, eq, compare, hash, yojson]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = T.Stable.V1.t Poly.Stable.V1.t
    [@@deriving sexp, eq, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

(*type 'a t_ = 'a Poly.t = {slot_number: 'a; slots_per_epoch: 'a}
[@@deriving sexp, eq, compare, hash, yojson]*)

type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash, yojson]

type value = t [@@deriving sexp, eq, compare, hash, yojson]

type var = T.Checked.var Poly.t

let to_hlist ({slot_number; slots_per_epoch} : 'a Poly.t) =
  H_list.[slot_number; slots_per_epoch]

let of_hlist : (unit, 'a -> 'a -> unit) H_list.t -> 'a Poly.t =
 fun H_list.[slot_number; slots_per_epoch] -> {slot_number; slots_per_epoch}

let data_spec = Data_spec.[T.Checked.typ; T.Checked.typ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let to_input (t : value) =
  Random_oracle.Input.bitstrings
    (Array.map ~f:T.to_bits [|t.slot_number; t.slots_per_epoch|])

let gen =
  let open Quickcheck.Let_syntax in
  let slots_per_epoch =
    Coda_constants.compiled_constants_for_test.consensus.slots_per_epoch
    |> T.of_int
  in
  let%map slot_number = T.gen in
  {Poly.slot_number; slots_per_epoch}

let create ~(epoch : Epoch.t) ~(slot : Slot.t) ~slots_per_epoch : t =
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

let start_time t =
  let epoch, slot = to_epoch_and_slot t in
  Epoch.slot_start_time epoch slot

let end_time t =
  let epoch, slot = to_epoch_and_slot t in
  Epoch.slot_end_time epoch slot

let time_hum t =
  let epoch, slot = to_epoch_and_slot t in
  sprintf "epoch=%d, slot=%d" (Epoch.to_int epoch) (Slot.to_int slot)

let of_time_exn time =
  Core.printf "6\n%!" ;
  let slots_per_epoch =
    (Coda_constants.t ()).consensus.slots_per_epoch |> T.of_int
  in
  of_epoch_and_slot (Epoch.epoch_and_slot_of_time_exn time) ~slots_per_epoch

let diff (t : t) (other_epoch, other_slot) ~epoch_size =
  let open UInt32.Infix in
  let epoch, slot = to_epoch_and_slot t in
  let old_epoch =
    epoch - other_epoch - (UInt32.of_int @@ if other_slot > slot then 1 else 0)
  in
  let old_slot = (slot - other_slot) mod epoch_size in
  of_epoch_and_slot (old_epoch, old_slot) ~slots_per_epoch:t.slots_per_epoch

module Checked = struct
  type t = var

  let ( < ) (t : t) (t' : t) = T.Checked.(t.slot_number < t'.slot_number)

  let to_bits (t : t) =
    let open Bitstring_lib.Bitstring.Lsb_first in
    let%map slot_number = T.Checked.to_bits t.slot_number
    and slots_per_epoch = T.Checked.to_bits t.slots_per_epoch in
    List.concat_map ~f:to_list [slot_number; slots_per_epoch] |> of_list

  let to_input (var : t) =
    let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
    let%map slot_number = T.Checked.to_bits var.slot_number
    and slots_per_epoch = T.Checked.to_bits var.slots_per_epoch in
    Random_oracle.Input.bitstrings
      (Array.map ~f:s [|slot_number; slots_per_epoch|])

  let to_epoch_and_slot (t : t) :
      (Epoch.Checked.t * Slot.Checked.t, _) Checked.t =
    make_checked (fun () ->
        let open Snarky_integer in
        let epoch, slot =
          Integer.div_mod ~m
            (T.Checked.to_integer t.slot_number)
            (T.Checked.to_integer t.slots_per_epoch)
        in
        ( Epoch.Checked.Unsafe.of_integer epoch
        , Slot.Checked.Unsafe.of_integer slot ) )
end
