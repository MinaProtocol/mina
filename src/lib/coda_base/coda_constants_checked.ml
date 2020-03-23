(*[%%import
"/src/config.mlh"]*)
open Core_kernel
open Unsigned

module T = Coda_numbers.Nat.Make32 ()

(*[%%ifdef
consensus_mechanism]*)

open Snark_params.Tick

(*[%%else]

open Snark_params_nonconsensus

[%%endif]*)
module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (*type ( 'k
           , 'c
           , 'slots_per_epoch
           , 'slots_per_sub_window
           , 'sub_windows_per_window
           , 'checkpoint_window_size_in_slots )
           t =
        { k: 'k
        ; c: 'c
        ; slots_per_epoch: 'slots_per_epoch
        ; slots_per_sub_window: 'slots_per_sub_window
        ; sub_windows_per_window: 'sub_windows_per_window
        ; checkpoint_window_size_in_slots: 'checkpoint_window_size_in_slots }*)

      type 'a t =
        { k: 'a
        ; c: 'a
        ; slots_per_epoch: 'a
        ; slots_per_sub_window: 'a
        ; sub_windows_per_window: 'a
        ; checkpoint_window_size_in_slots: 'a }
      [@@deriving bin_io, sexp, eq, compare, to_yojson, hash]
    end
  end]

  type 'a t = 'a Stable.Latest.t =
    { k: 'a
    ; c: 'a
    ; slots_per_epoch: 'a
    ; slots_per_sub_window: 'a
    ; sub_windows_per_window: 'a
    ; checkpoint_window_size_in_slots: 'a }
  [@@deriving sexp]
end

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = T.Stable.V1.t Poly.Stable.V1.t
      [@@deriving eq, ord, bin_io, hash, sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type 'a t_ = 'a Poly.t =
    { k: 'a
    ; c: 'a
    ; slots_per_epoch: 'a
    ; slots_per_sub_window: 'a
    ; sub_windows_per_window: 'a
    ; checkpoint_window_size_in_slots: 'a }
  [@@deriving sexp, to_yojson]

  type t = T.t t_ [@@deriving sexp, to_yojson]
end

type value = Value.t [@@deriving sexp, to_yojson]

type var = T.Checked.var Poly.t

let to_hlist
    ({ k
     ; c
     ; slots_per_epoch
     ; slots_per_sub_window
     ; sub_windows_per_window
     ; checkpoint_window_size_in_slots } :
      'a Poly.t) =
  H_list.
    [ k
    ; c
    ; slots_per_epoch
    ; slots_per_sub_window
    ; sub_windows_per_window
    ; checkpoint_window_size_in_slots ]

let of_hlist :
    (unit, 'a -> 'a -> 'a -> 'a -> 'a -> 'a -> unit) H_list.t -> 'a Poly.t =
 fun H_list.
       [ k
       ; c
       ; slots_per_epoch
       ; slots_per_sub_window
       ; sub_windows_per_window
       ; checkpoint_window_size_in_slots ] ->
  { k
  ; c
  ; slots_per_epoch
  ; slots_per_sub_window
  ; sub_windows_per_window
  ; checkpoint_window_size_in_slots }

let data_spec =
  Data_spec.
    [ T.Checked.typ
    ; T.Checked.typ
    ; T.Checked.typ
    ; T.Checked.typ
    ; T.Checked.typ
    ; T.Checked.typ ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let of_coda_constants (coda_constants : Coda_constants.t) : value =
  let open UInt32 in
  { k= of_int coda_constants.consensus.k
  ; c= of_int coda_constants.consensus.c
  ; slots_per_epoch= of_int coda_constants.consensus.slots_per_epoch
  ; slots_per_sub_window= of_int coda_constants.consensus.slots_per_sub_window
  ; sub_windows_per_window=
      of_int coda_constants.consensus.sub_windows_per_window
  ; checkpoint_window_size_in_slots=
      of_int coda_constants.consensus.checkpoint_window_size_in_slots }

let to_input (t : value) =
  Random_oracle.Input.bitstrings
    (Array.map ~f:T.to_bits
       [| t.k
        ; t.c
        ; t.slots_per_epoch
        ; t.slots_per_sub_window
        ; t.sub_windows_per_window
        ; t.checkpoint_window_size_in_slots |])

let var_to_input (var : var) =
  let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
  let%map k = T.Checked.to_bits var.k
  and c = T.Checked.to_bits var.c
  and slots_per_epoch = T.Checked.to_bits var.slots_per_epoch
  and slots_per_sub_window = T.Checked.to_bits var.slots_per_sub_window
  and sub_windows_per_window = T.Checked.to_bits var.sub_windows_per_window
  and checkpoint_window_size_in_slots =
    T.Checked.to_bits var.checkpoint_window_size_in_slots
  in
  Random_oracle.Input.bitstrings
    (Array.map ~f:s
       [| k
        ; c
        ; slots_per_epoch
        ; slots_per_sub_window
        ; sub_windows_per_window
        ; checkpoint_window_size_in_slots |])

let to_slot_var :
    T.Checked.t -> (Coda_numbers.Global_slot.Checked.t, _) Checked.t =
 fun t ->
  let%map bits = T.Checked.to_bits t in
  Coda_numbers.Global_slot.Checked.of_bits bits

(*type 'a tree = Empty | Node of 'a * 'a forest

and 'a forest = Nil | Cons of 'a tree * 'a forest [@@deriving sexp]


type 'a instr = Instr of 'a | Define of string * 'a program
and 'a program = Empty | Non_empty of 'a instr * 'a program

let rec program_rec : 'c -> ('a -> 'c) -> (string -> 'c -> 'c) -> ('c -> 'c -> 'c) -> 'a program -> 'c =
  fun init fa fb fc program ->
  match program with
  | Empty -> init
  | Non_empty (i, p) -> fc (instr_rec  init fa fb fc i) (program_rec init fa fb fc p)
and instr_rec init fa fb fc ins =
  match ins with
  | Instr a -> fa a
  | Define (s, p) -> fb s (program_rec init fa fb fc p)


let rec forest_recursor :
    'c -> ('a -> 'c -> 'c) -> ('c -> 'c -> 'c) -> 'a forest -> 'c =
 fun init fa fc forest ->
  match forest with
  | Nil ->
      init
  | Cons (tree', forest') ->
      fc (tree_recursor init fa fc tree') (forest_recursor init fa fc forest')

and tree_recursor : 'c -> ('a -> 'c -> 'c) -> ('c -> 'c -> 'c) -> 'a tree -> 'c
    =
 fun init fa fc tree ->
  match tree with
  | Empty ->
      init
  | Node (a, forest') ->
      fa a (forest_recursor init fa fc forest')

let () =
  let empty_forest = Nil in
  let forest = Cons (Node ("x", Nil), Nil) in
  let value1 = forest_recursor "!" ( ^ ) ( ^ ) empty_forest in
  let value2 = forest_recursor "!" ( ^ ) ( ^ ) forest in
  Core.printf !"%s %s\n%!" value1 value2*)
