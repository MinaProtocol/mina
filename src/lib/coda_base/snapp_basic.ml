[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
open Signature_lib

[%%else]

open Signature_lib_nonconsensus

[%%endif]

module Flagged_option = struct
  type ('bool, 'a) t = {is_some: 'bool; data: 'a} [@@deriving hlist, fields]

  let typ t =
    Typ.of_hlistable [Boolean.typ; t] ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let to_input' {is_some; data} ~f =
    Random_oracle_input.(append (bitstring [is_some]) (f data))

  let to_input {is_some; data} ~default ~f =
    let data = if is_some then data else default in
    to_input' {is_some; data} ~f

  let of_option t ~default =
    match t with
    | None ->
        {is_some= false; data= default}
    | Some data ->
        {is_some= true; data}

  let to_option {is_some; data} = Option.some_if is_some data

  let option_typ ~default t =
    Typ.transport (typ t) ~there:(of_option ~default) ~back:to_option
end

module Set_or_keep = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = Set of 'a | Keep
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t = Set of 'a | Keep

  let to_option = function Set x -> Some x | Keep -> None

  let of_option = function Some x -> Set x | None -> Keep

  let set_or_keep t x = match t with Keep -> x | Set y -> y

  module Checked : sig
    type 'a t

    val is_keep : _ t -> Boolean.var

    val is_set : _ t -> Boolean.var

    val data : 'a t -> 'a

    val typ :
      dummy:'a -> ('a_var, 'a) Typ.t -> ('a_var t, 'a Stable.Latest.t) Typ.t

    val to_input :
         'a t
      -> f:('a -> ('f, Boolean.var) Random_oracle_input.t)
      -> ('f, Boolean.var) Random_oracle_input.t
  end = struct
    type 'a t = (Boolean.var, 'a) Flagged_option.t

    let data = Flagged_option.data

    let is_set = Flagged_option.is_some

    let is_keep x = Boolean.not (Flagged_option.is_some x)

    let typ ~dummy t =
      Typ.transport
        (Flagged_option.option_typ ~default:dummy t)
        ~there:to_option ~back:of_option

    let to_input (t : _ t) ~f = Flagged_option.to_input' t ~f
  end

  let typ = Checked.typ

  let to_input t ~dummy:default ~f =
    Flagged_option.to_input ~default ~f
      (Flagged_option.of_option ~default (to_option t))
end

module Or_ignore = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = Check of 'a | Ignore
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t = Check of 'a | Ignore

  module Checked : sig
    type 'a t

    val typ_implicit :
         equal:('a -> 'a -> bool)
      -> ignore:'a
      -> ('a_var, 'a) Typ.t
      -> ('a_var t, 'a Stable.Latest.t) Typ.t

    val typ_explicit :
      ignore:'a -> ('a_var, 'a) Typ.t -> ('a_var t, 'a Stable.Latest.t) Typ.t

    val to_input :
         'a t
      -> f:('a -> ('f, Boolean.var) Random_oracle_input.t)
      -> ('f, Boolean.var) Random_oracle_input.t
  end = struct
    type 'a t =
      | Implicit of 'a
      | Explicit of (Boolean.var, 'a) Flagged_option.t

    let to_input t ~f =
      match t with
      | Implicit x ->
          f x
      | Explicit t ->
          Flagged_option.to_input' t ~f

    let typ_implicit (type a a_var) ~equal ~(ignore : a) (t : (a_var, a) Typ.t)
        : (a_var t, a Stable.Latest.t) Typ.t =
      Typ.transport t
        ~there:(function Check x -> x | Ignore -> ignore)
        ~back:(fun x -> if equal x ignore then Ignore else Check x)
      |> Typ.transport_var
           ~there:(function Implicit x -> x | Explicit _ -> assert false)
           ~back:(fun x -> Implicit x)

    let typ_explicit (type a_var a) ~ignore (t : (a_var, a) Typ.t) =
      Typ.transport_var
        (Flagged_option.option_typ ~default:ignore t)
        ~there:(function Implicit _ -> assert false | Explicit t -> t)
        ~back:(fun t -> Explicit t)
      |> Typ.transport
           ~there:(function Ignore -> None | Check x -> Some x)
           ~back:(function None -> Ignore | Some x -> Check x)
  end

  let typ_implicit = Checked.typ_implicit

  let typ_explicit = Checked.typ_explicit
end

module F = Pickles.Backend.Tick.Field

let invalid_public_key : Public_key.Compressed.t Lazy.t =
  let open F in
  let f x =
    let open Pickles.Backend.Tick.Inner_curve.Params in
    b + (x * (a + square x))
  in
  let rec go i : Public_key.Compressed.t =
    if not (is_square (f i)) then {x= i; is_odd= false} else go (i + one)
  in
  lazy (go zero)
