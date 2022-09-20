[%%import "/src/config.mlh"]

open Core_kernel

let field_of_bool = Mina_base_util.field_of_bool

[%%ifdef consensus_mechanism]

open Snark_params.Tick
open Signature_lib

[%%endif]

let int_to_bits ~length x = List.init length ~f:(fun i -> (x lsr i) land 1 = 1)

let int_of_bits =
  List.foldi ~init:0 ~f:(fun i acc b -> if b then acc lor (1 lsl i) else acc)

module Transition = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = { prev : 'a; next : 'a }
      [@@deriving hlist, sexp, equal, yojson, hash, compare]
    end
  end]

  let to_input { prev; next } ~f =
    Random_oracle_input.Chunked.append (f prev) (f next)

  [%%ifdef consensus_mechanism]

  let typ t =
    Typ.of_hlistable [ t; t ] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  [%%endif]
end

module Flagged_data = struct
  type ('flag, 'a) t = { flag : 'flag; data : 'a } [@@deriving hlist, fields]

  [%%ifdef consensus_mechanism]

  let typ flag t =
    Typ.of_hlistable [ flag; t ] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  [%%endif]

  let to_input' { flag; data } ~flag:f ~data:d =
    Random_oracle_input.Chunked.(append (f flag) (d data))
end

module Flagged_option = struct
  type ('bool, 'a) t = { is_some : 'bool; data : 'a } [@@deriving hlist, fields]

  let to_input' ~field_of_bool { is_some; data } ~f =
    Random_oracle_input.Chunked.(
      append (packed (field_of_bool is_some, 1)) (f data))

  let to_input { is_some; data } ~default ~f =
    let data = if is_some then data else default in
    to_input' { is_some; data } ~f

  let of_option t ~default =
    match t with
    | None ->
        { is_some = false; data = default }
    | Some data ->
        { is_some = true; data }

  let to_option { is_some; data } = Option.some_if is_some data

  let map ~f { is_some; data } = { is_some; data = f data }

  [%%ifdef consensus_mechanism]

  let if_ ~(if_ : 'b -> then_:'var -> else_:'var -> 'var) b ~then_ ~else_ =
    { is_some =
        Run.run_checked
          (Boolean.if_ b ~then_:then_.is_some ~else_:else_.is_some)
    ; data = if_ b ~then_:then_.data ~else_:else_.data
    }

  let typ t =
    Typ.of_hlistable [ Boolean.typ; t ] ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let option_typ ~default t =
    Typ.transport (typ t) ~there:(of_option ~default) ~back:to_option

  [%%endif]
end

module Set_or_keep = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = 'a Mina_wire_types.Mina_base.Zkapp_basic.Set_or_keep.V1.t =
        | Set of 'a
        | Keep
      [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  let map t ~f = match t with Keep -> Keep | Set x -> Set (f x)

  let to_option = function Set x -> Some x | Keep -> None

  let of_option = function Some x -> Set x | None -> Keep

  let set_or_keep t x = match t with Keep -> x | Set y -> y

  let is_set = function Set _ -> true | _ -> false

  let is_keep = function Keep -> true | _ -> false

  let deriver inner obj =
    let open Fields_derivers_zkapps.Derivers in
    iso ~map:of_option ~contramap:to_option
      ((option ~js_type:`Flagged_option @@ inner @@ o ()) (o ()))
      obj

  let gen gen_a =
    let open Quickcheck.Let_syntax in
    (* with equal probability, return a Set or a Keep *)
    let%bind b = Quickcheck.Generator.bool in
    if b then
      let%bind a = gen_a in
      return (Set a)
    else return Keep

  [%%ifdef consensus_mechanism]

  module Checked : sig
    type 'a t

    val is_keep : _ t -> Boolean.var

    val is_set : _ t -> Boolean.var

    val set_or_keep :
      if_:(Boolean.var -> then_:'a -> else_:'a -> 'a) -> 'a t -> 'a -> 'a

    val data : 'a t -> 'a

    val typ :
      dummy:'a -> ('a_var, 'a) Typ.t -> ('a_var t, 'a Stable.Latest.t) Typ.t

    val optional_typ :
         to_option:('new_value -> 'value option)
      -> of_option:('value option -> 'new_value)
      -> ('var, 'new_value) Typ.t
      -> ('var t, 'value Stable.Latest.t) Typ.t

    val map : f:('a -> 'b) -> 'a t -> 'b t

    val to_input :
         'a t
      -> f:('a -> Field.Var.t Random_oracle_input.Chunked.t)
      -> Field.Var.t Random_oracle_input.Chunked.t

    val set : 'a -> 'a t

    val keep : dummy:'a -> 'a t

    val make_unsafe : Boolean.var -> 'a -> 'a t
  end = struct
    type 'a t = (Boolean.var, 'a) Flagged_option.t

    let set_or_keep ~if_ ({ is_some; data } : _ t) x =
      if_ is_some ~then_:data ~else_:x

    let data = Flagged_option.data

    let is_set = Flagged_option.is_some

    let is_keep x = Boolean.not (Flagged_option.is_some x)

    let map = Flagged_option.map

    let typ ~dummy t =
      Typ.transport
        (Flagged_option.option_typ ~default:dummy t)
        ~there:to_option ~back:of_option

    let optional_typ (type new_value value var) :
           to_option:(new_value -> value option)
        -> of_option:(value option -> new_value)
        -> (var, new_value) Typ.t
        -> (var t, value Stable.Latest.t) Typ.t =
     fun ~to_option ~of_option t ->
      Typ.transport (Flagged_option.typ t)
        ~there:(function
          | Set x ->
              { Flagged_option.is_some = true; data = of_option (Some x) }
          | Keep ->
              { Flagged_option.is_some = false; data = of_option None } )
        ~back:(function
          | { Flagged_option.is_some = true; data = x } ->
              Set (Option.value_exn (to_option x))
          | { Flagged_option.is_some = false; data = _ } ->
              Keep )

    let to_input (t : _ t) ~f =
      Flagged_option.to_input' t ~f ~field_of_bool:(fun (b : Boolean.var) ->
          (b :> Field.Var.t) )

    let make_unsafe is_keep data = { Flagged_option.is_some = is_keep; data }

    let set data = { Flagged_option.is_some = Boolean.true_; data }

    let keep ~dummy = { Flagged_option.is_some = Boolean.false_; data = dummy }
  end

  let typ = Checked.typ

  let optional_typ = Checked.optional_typ

  [%%endif]

  let to_input t ~dummy:default ~f =
    Flagged_option.to_input ~default ~f ~field_of_bool
      (Flagged_option.of_option ~default (to_option t))
end

module Or_ignore = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = 'a Mina_wire_types.Mina_base.Zkapp_basic.Or_ignore.V1.t =
        | Check of 'a
        | Ignore
      [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  let gen gen_a =
    let open Quickcheck.Let_syntax in
    (* choose constructor *)
    let%bind b = Quickcheck.Generator.bool in
    if b then
      let%map a = gen_a in
      Check a
    else return Ignore

  let to_option = function Ignore -> None | Check x -> Some x

  let of_option = function None -> Ignore | Some x -> Check x

  let deriver_base ~js_type inner obj =
    let open Fields_derivers_zkapps.Derivers in
    iso ~map:of_option ~contramap:to_option
      ((option ~js_type @@ inner @@ o ()) (o ()))
      obj

  let deriver inner obj = deriver_base ~js_type:`Flagged_option inner obj

  [%%ifdef consensus_mechanism]

  module Checked : sig
    type 'a t

    val typ :
      ignore:'a -> ('a_var, 'a) Typ.t -> ('a_var t, 'a Stable.Latest.t) Typ.t

    val to_input :
         'a t
      -> f:('a -> Field.Var.t Random_oracle_input.Chunked.t)
      -> Field.Var.t Random_oracle_input.Chunked.t

    val check : 'a t -> f:('a -> Boolean.var) -> Boolean.var

    val map : f:('a -> 'b) -> 'a t -> 'b t

    val data : 'a t -> 'a

    val is_check : 'a t -> Boolean.var

    val make_unsafe : Boolean.var -> 'a -> 'a t
  end = struct
    type 'a t = (Boolean.var, 'a) Flagged_option.t

    let to_input t ~f =
      Flagged_option.to_input' t ~f ~field_of_bool:(fun (b : Boolean.var) ->
          (b :> Field.Var.t) )

    let check { Flagged_option.is_some; data } ~f =
      Pickles.Impls.Step.Boolean.(any [ not is_some; f data ])

    let map = Flagged_option.map

    let data = Flagged_option.data

    let is_check = Flagged_option.is_some

    let typ (type a_var a) ~ignore (t : (a_var, a) Typ.t) =
      Typ.transport
        (Flagged_option.option_typ ~default:ignore t)
        ~there:to_option ~back:of_option

    let make_unsafe is_ignore data =
      { Flagged_option.is_some = is_ignore; data }
  end

  let typ = Checked.typ

  [%%endif]
end

module Account_state = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Empty | Non_empty | Any
      [@@deriving sexp, equal, yojson, hash, compare, enum]

      let to_latest = Fn.id
    end
  end]

  module Encoding = struct
    type 'b t = { any : 'b; empty : 'b } [@@deriving hlist]

    let to_input ~field_of_bool { any; empty } =
      Random_oracle_input.Chunked.packeds
        [| (field_of_bool any, 1); (field_of_bool empty, 1) |]
  end

  let encode : t -> bool Encoding.t = function
    | Empty ->
        { any = false; empty = true }
    | Non_empty ->
        { any = false; empty = false }
    | Any ->
        { any = true; empty = false }

  let decode : bool Encoding.t -> t = function
    | { any = false; empty = true } ->
        Empty
    | { any = false; empty = false } ->
        Non_empty
    | { any = true; empty = false } | { any = true; empty = true } ->
        Any

  let to_input (x : t) = Encoding.to_input ~field_of_bool (encode x)

  let check (t : t) (x : [ `Empty | `Non_empty ]) =
    match (t, x) with
    | Any, _ | Non_empty, `Non_empty | Empty, `Empty ->
        Ok ()
    | _ ->
        Or_error.error_string "Bad account_type"

  [%%ifdef consensus_mechanism]

  module Checked = struct
    open Pickles.Impls.Step

    type t = Boolean.var Encoding.t

    let to_input (t : t) =
      Encoding.to_input t ~field_of_bool:(fun (b : Boolean.var) ->
          (b :> Field.t) )

    let check (t : t) ~is_empty =
      Boolean.(
        any [ t.any; t.empty && is_empty; (not t.empty) && not is_empty ])
  end

  let typ : (Checked.t, t) Typ.t =
    let open Encoding in
    Typ.of_hlistable
      [ Boolean.typ; Boolean.typ ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
    |> Typ.transport ~there:encode ~back:decode

  [%%endif]
end

[%%ifdef consensus_mechanism]

module F = Pickles.Backend.Tick.Field

[%%else]

module F = Snark_params.Tick.Field

[%%endif]

let invalid_public_key : Public_key.Compressed.t =
  { x = F.zero; is_odd = false }

let%test "invalid_public_key is invalid" =
  Option.is_none (Public_key.decompress invalid_public_key)
