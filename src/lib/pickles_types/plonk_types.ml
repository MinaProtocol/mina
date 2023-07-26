open Core_kernel

let padded_array_typ ~length ~dummy elt =
  Snarky_backendless.Typ.array ~length elt
  |> Snarky_backendless.Typ.transport
       ~there:(fun a ->
         let n = Array.length a in
         if n > length then failwithf "Expected %d <= %d" n length () ;
         Array.append a (Array.create ~len:(length - n) dummy) )
       ~back:Fn.id

let hash_fold_array f s x = hash_fold_list f s (Array.to_list x)

module Columns = Nat.N15
module Columns_vec = Vector.Vector_15
module Permuts_minus_1 = Nat.N6
module Permuts_minus_1_vec = Vector.Vector_6
module Permuts = Nat.N7
module Permuts_vec = Vector.Vector_7
module Lookup_sorted_vec = Vector.Vector_5

module Opt = struct
  [@@@warning "-4"]

  type ('a, 'bool) t = Some of 'a | None | Maybe of 'bool * 'a
  [@@deriving sexp, compare, yojson, hash, equal]

  let to_option : ('a, bool) t -> 'a option = function
    | Some x ->
        Some x
    | Maybe (true, x) ->
        Some x
    | Maybe (false, _x) ->
        None
    | None ->
        None

  let to_option_unsafe : ('a, 'bool) t -> 'a option = function
    | Some x ->
        Some x
    | Maybe (_, x) ->
        Some x
    | None ->
        None

  let value_exn = function
    | Some x ->
        x
    | Maybe (_, x) ->
        x
    | None ->
        invalid_arg "Opt.value_exn"

  let of_option (t : 'a option) : ('a, 'bool) t =
    match t with None -> None | Some x -> Some x

  module Flag = struct
    type t = Yes | No | Maybe [@@deriving sexp, compare, yojson, hash, equal]

    let ( ||| ) x y =
      match (x, y) with
      | Yes, _ | _, Yes ->
          Yes
      | Maybe, _ | _, Maybe ->
          Maybe
      | No, No ->
          No
  end

  let map t ~f =
    match t with
    | None ->
        None
    | Some x ->
        Some (f x)
    | Maybe (b, x) ->
        Maybe (b, f x)

  open Snarky_backendless

  let some_typ (type a a_var f bool_var) (t : (a_var, a, f) Typ.t) :
      ((a_var, bool_var) t, a option, f) Typ.t =
    Typ.transport t ~there:(fun x -> Option.value_exn x) ~back:Option.return
    |> Typ.transport_var
         ~there:(function
           | Some x ->
               x
           | Maybe _ | None ->
               failwith "Opt.some_typ: expected Some" )
         ~back:(fun x -> Some x)

  let none_typ (type a a_var f bool) () : ((a_var, bool) t, a option, f) Typ.t =
    Typ.transport (Typ.unit ())
      ~there:(fun _ -> ())
      ~back:(fun () : _ Option.t -> None)
    |> Typ.transport_var
         ~there:(function
           | None ->
               ()
           | Maybe _ | Some _ ->
               failwith "Opt.none_typ: expected None" )
         ~back:(fun () : _ t -> None)

  let maybe_typ (type a a_var bool_var f)
      (bool_typ : (bool_var, bool, f) Snarky_backendless.Typ.t) ~(dummy : a)
      (a_typ : (a_var, a, f) Typ.t) : ((a_var, bool_var) t, a option, f) Typ.t =
    Typ.transport
      (Typ.tuple2 bool_typ a_typ)
      ~there:(fun (t : a option) ->
        match t with None -> (false, dummy) | Some x -> (true, x) )
      ~back:(fun (b, x) -> if b then Some x else None)
    |> Typ.transport_var
         ~there:(fun (t : (a_var, _) t) ->
           match t with
           | Maybe (b, x) ->
               (b, x)
           | None | Some _ ->
               failwith "Opt.maybe_typ: expected Maybe" )
         ~back:(fun (b, x) -> Maybe (b, x))

  let constant_layout_typ (type a a_var f) (bool_typ : _ Typ.t) ~true_ ~false_
      (flag : Flag.t) (a_typ : (a_var, a, f) Typ.t) ~(dummy : a)
      ~(dummy_var : a_var) =
    let (Typ bool_typ) = bool_typ in
    let bool_typ : _ Typ.t =
      let check =
        (* No need to boolean constrain in the No or Yes case *)
        match flag with
        | No | Yes ->
            fun _ -> Checked_runner.Simple.return ()
        | Maybe ->
            bool_typ.check
      in
      Typ { bool_typ with check }
    in
    Typ.transport
      (Typ.tuple2 bool_typ a_typ)
      ~there:(fun (t : a option) ->
        match t with None -> (false, dummy) | Some x -> (true, x) )
      ~back:(fun (b, x) -> if b then Some x else None)
    |> Typ.transport_var
         ~there:(fun (t : (a_var, _) t) ->
           match t with
           | Maybe (b, x) ->
               (b, x)
           | None ->
               (false_, dummy_var)
           | Some x ->
               (true_, x) )
         ~back:(fun (b, x) ->
           match flag with No -> None | Yes -> Some x | Maybe -> Maybe (b, x) )

  let typ (type a a_var f) bool_typ (flag : Flag.t)
      (a_typ : (a_var, a, f) Typ.t) ~(dummy : a) =
    match flag with
    | Yes ->
        some_typ a_typ
    | No ->
        none_typ ()
    | Maybe ->
        maybe_typ bool_typ ~dummy a_typ

  module Early_stop_sequence = struct
    (* A sequence that should be considered to have stopped at
       the first No flag *)
    (* TODO: The documentation above makes it sound like the type below is too
       generic: we're not guaranteed to have flags in there *)
    type nonrec ('a, 'bool) t = ('a, 'bool) t list

    let fold (type a bool acc res)
        (if_res : bool -> then_:res -> else_:res -> res) (t : (a, bool) t)
        ~(init : acc) ~(f : acc -> a -> acc) ~(finish : acc -> res) =
      let rec go acc = function
        | [] ->
            finish acc
        | None :: xs ->
            go acc xs
        | Some x :: xs ->
            go (f acc x) xs
        | Maybe (b, x) :: xs ->
            (* Computing this first makes mutation in f OK. *)
            let stop_res = finish acc in
            let continue_res = go (f acc x) xs in
            if_res b ~then_:continue_res ~else_:stop_res
      in
      go init t
  end
end

module Features = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'bool t =
        { range_check0 : 'bool
        ; range_check1 : 'bool
        ; foreign_field_add : 'bool
        ; foreign_field_mul : 'bool
        ; xor : 'bool
        ; rot : 'bool
        ; lookup : 'bool
        ; runtime_tables : 'bool
        }
      [@@deriving sexp, compare, yojson, hash, equal, hlist]
    end
  end]

  type options = Opt.Flag.t t

  type flags = bool t

  let to_data
      { range_check0
      ; range_check1
      ; foreign_field_add
      ; foreign_field_mul
      ; xor
      ; rot
      ; lookup
      ; runtime_tables
      } : _ Hlist.HlistId.t =
    [ range_check0
    ; range_check1
    ; foreign_field_add
    ; foreign_field_mul
    ; xor
    ; rot
    ; lookup
    ; runtime_tables
    ]

  let of_data
      ([ range_check0
       ; range_check1
       ; foreign_field_add
       ; foreign_field_mul
       ; xor
       ; rot
       ; lookup
       ; runtime_tables
       ] :
        _ Hlist.HlistId.t ) =
    { range_check0
    ; range_check1
    ; foreign_field_add
    ; foreign_field_mul
    ; xor
    ; rot
    ; lookup
    ; runtime_tables
    }

  let typ bool
      ~feature_flags:
        { range_check0
        ; range_check1
        ; foreign_field_add
        ; foreign_field_mul
        ; xor
        ; rot
        ; lookup
        ; runtime_tables
        } =
    (* TODO: This should come from snarky. *)
    let constant (type var value)
        (typ : (var, value, _) Snarky_backendless.Typ.t) (x : value) : var =
      let (Typ typ) = typ in
      let fields, aux = typ.value_to_fields x in
      let fields =
        Array.map ~f:(fun x -> Snarky_backendless.Cvar.Constant x) fields
      in
      typ.var_of_fields (fields, aux)
    in
    let constant_typ ~there value =
      let open Snarky_backendless.Typ in
      unit ()
      |> transport ~there ~back:(fun () -> value)
      |> transport_var ~there:(fun _ -> ()) ~back:(fun () -> constant bool value)
    in
    let bool_typ_of_flag = function
      | Opt.Flag.Yes ->
          constant_typ
            ~there:(function true -> () | false -> assert false)
            true
      | Opt.Flag.No ->
          constant_typ
            ~there:(function false -> () | true -> assert false)
            false
      | Opt.Flag.Maybe ->
          bool
    in
    Snarky_backendless.Typ.of_hlistable
      [ bool_typ_of_flag range_check0
      ; bool_typ_of_flag range_check1
      ; bool_typ_of_flag foreign_field_add
      ; bool_typ_of_flag foreign_field_mul
      ; bool_typ_of_flag xor
      ; bool_typ_of_flag rot
      ; bool_typ_of_flag lookup
      ; bool_typ_of_flag runtime_tables
      ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let none =
    { range_check0 = Opt.Flag.No
    ; range_check1 = Opt.Flag.No
    ; foreign_field_add = Opt.Flag.No
    ; foreign_field_mul = Opt.Flag.No
    ; xor = Opt.Flag.No
    ; rot = Opt.Flag.No
    ; lookup = Opt.Flag.No
    ; runtime_tables = Opt.Flag.No
    }

  let none_bool =
    { range_check0 = false
    ; range_check1 = false
    ; foreign_field_add = false
    ; foreign_field_mul = false
    ; xor = false
    ; rot = false
    ; lookup = false
    ; runtime_tables = false
    }

  let map
      { range_check0
      ; range_check1
      ; foreign_field_add
      ; foreign_field_mul
      ; rot
      ; xor
      ; lookup
      ; runtime_tables
      } ~f =
    { range_check0 = f range_check0
    ; range_check1 = f range_check1
    ; foreign_field_add = f foreign_field_add
    ; foreign_field_mul = f foreign_field_mul
    ; xor = f xor
    ; rot = f rot
    ; lookup = f lookup
    ; runtime_tables = f runtime_tables
    }

  let map2 x1 x2 ~f =
    { range_check0 = f x1.range_check0 x2.range_check0
    ; range_check1 = f x1.range_check1 x2.range_check1
    ; foreign_field_add = f x1.foreign_field_add x2.foreign_field_add
    ; foreign_field_mul = f x1.foreign_field_mul x2.foreign_field_mul
    ; xor = f x1.xor x2.xor
    ; rot = f x1.rot x2.rot
    ; lookup = f x1.lookup x2.lookup
    ; runtime_tables = f x1.runtime_tables x2.runtime_tables
    }
end

module Evals = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'a t =
        { w : 'a Columns_vec.Stable.V1.t
        ; coefficients : 'a Columns_vec.Stable.V1.t
        ; z : 'a
        ; s : 'a Permuts_minus_1_vec.Stable.V1.t
        ; generic_selector : 'a
        ; poseidon_selector : 'a
        ; complete_add_selector : 'a
        ; mul_selector : 'a
        ; emul_selector : 'a
        ; endomul_scalar_selector : 'a
        ; range_check0_selector : 'a option
        ; range_check1_selector : 'a option
        ; foreign_field_add_selector : 'a option
        ; foreign_field_mul_selector : 'a option
        ; xor_selector : 'a option
        ; rot_selector : 'a option
        ; lookup_aggregation : 'a option
        ; lookup_table : 'a option
        ; lookup_sorted : 'a option Lookup_sorted_vec.Stable.V1.t
        ; runtime_lookup_table : 'a option
        ; runtime_lookup_table_selector : 'a option
        ; xor_lookup_selector : 'a option
        ; lookup_gate_lookup_selector : 'a option
        ; range_check_lookup_selector : 'a option
        ; foreign_field_mul_lookup_selector : 'a option
        }
      [@@deriving fields, sexp, compare, yojson, hash, equal, hlist]
    end
  end]

  let validate_feature_flags ~feature_flags:(f : bool Features.t)
      { w = _
      ; coefficients = _
      ; z = _
      ; s = _
      ; generic_selector = _
      ; poseidon_selector = _
      ; complete_add_selector = _
      ; mul_selector = _
      ; emul_selector = _
      ; endomul_scalar_selector = _
      ; range_check0_selector
      ; range_check1_selector
      ; foreign_field_add_selector
      ; foreign_field_mul_selector
      ; xor_selector
      ; rot_selector
      ; lookup_aggregation
      ; lookup_table
      ; lookup_sorted
      ; runtime_lookup_table
      ; runtime_lookup_table_selector
      ; xor_lookup_selector
      ; lookup_gate_lookup_selector
      ; range_check_lookup_selector
      ; foreign_field_mul_lookup_selector
      } =
    let enable_if x flag = Bool.(Option.is_some x = flag) in
    let range_check_lookup = f.range_check0 || f.range_check1 || f.rot in
    let lookups_per_row_4 = f.xor || range_check_lookup in
    let lookups_per_row_3 = lookups_per_row_4 || f.lookup in
    let lookups_per_row_2 = lookups_per_row_3 || f.foreign_field_mul in
    Array.reduce_exn ~f:( && )
      [| enable_if range_check0_selector f.range_check0
       ; enable_if range_check1_selector f.range_check1
       ; enable_if foreign_field_add_selector f.foreign_field_add
       ; enable_if foreign_field_mul_selector f.foreign_field_mul
       ; enable_if xor_selector f.xor
       ; enable_if rot_selector f.rot
       ; enable_if lookup_aggregation lookups_per_row_2
       ; enable_if lookup_table lookups_per_row_2
       ; Vector.foldi lookup_sorted ~init:true ~f:(fun i acc x ->
             let flag =
               (* NB: lookups_per_row + 1 in sorted, due to the lookup table. *)
               match i with
               | 0 | 1 | 2 ->
                   lookups_per_row_2
               | 3 ->
                   lookups_per_row_3
               | 4 ->
                   lookups_per_row_4
               | _ ->
                   assert false
             in
             acc && enable_if x flag )
       ; enable_if runtime_lookup_table f.runtime_tables
       ; enable_if runtime_lookup_table_selector f.runtime_tables
       ; enable_if xor_lookup_selector f.xor
       ; enable_if lookup_gate_lookup_selector f.lookup
       ; enable_if range_check_lookup_selector range_check_lookup
       ; enable_if foreign_field_mul_lookup_selector f.foreign_field_mul
      |]

  let to_absorption_sequence
      { w
      ; coefficients
      ; z
      ; s
      ; generic_selector
      ; poseidon_selector
      ; complete_add_selector
      ; mul_selector
      ; emul_selector
      ; endomul_scalar_selector
      ; range_check0_selector
      ; range_check1_selector
      ; foreign_field_add_selector
      ; foreign_field_mul_selector
      ; xor_selector
      ; rot_selector
      ; lookup_aggregation
      ; lookup_table
      ; lookup_sorted
      ; runtime_lookup_table
      ; runtime_lookup_table_selector
      ; xor_lookup_selector
      ; lookup_gate_lookup_selector
      ; range_check_lookup_selector
      ; foreign_field_mul_lookup_selector
      } : _ list =
    let always_present =
      [ z
      ; generic_selector
      ; poseidon_selector
      ; complete_add_selector
      ; mul_selector
      ; emul_selector
      ; endomul_scalar_selector
      ]
      @ Vector.to_list w
      @ Vector.to_list coefficients
      @ Vector.to_list s
    in
    let optional_gates =
      List.filter_map ~f:Fn.id
        [ range_check0_selector
        ; range_check1_selector
        ; foreign_field_add_selector
        ; foreign_field_mul_selector
        ; xor_selector
        ; rot_selector
        ; lookup_aggregation
        ; lookup_table
        ]
    in
    let lookup_final_terms =
      List.filter_map ~f:Fn.id
        [ runtime_lookup_table
        ; runtime_lookup_table_selector
        ; xor_lookup_selector
        ; lookup_gate_lookup_selector
        ; range_check_lookup_selector
        ; foreign_field_mul_lookup_selector
        ]
    in
    always_present @ optional_gates
    @ List.filter_map ~f:Fn.id (Vector.to_list lookup_sorted)
    @ lookup_final_terms

  module In_circuit = struct
    type ('f, 'bool) t =
      { w : 'f Columns_vec.t
      ; coefficients : 'f Columns_vec.t
      ; z : 'f
      ; s : 'f Permuts_minus_1_vec.t
      ; generic_selector : 'f
      ; poseidon_selector : 'f
      ; complete_add_selector : 'f
      ; mul_selector : 'f
      ; emul_selector : 'f
      ; endomul_scalar_selector : 'f
      ; range_check0_selector : ('f, 'bool) Opt.t
      ; range_check1_selector : ('f, 'bool) Opt.t
      ; foreign_field_add_selector : ('f, 'bool) Opt.t
      ; foreign_field_mul_selector : ('f, 'bool) Opt.t
      ; xor_selector : ('f, 'bool) Opt.t
      ; rot_selector : ('f, 'bool) Opt.t
      ; lookup_aggregation : ('f, 'bool) Opt.t
      ; lookup_table : ('f, 'bool) Opt.t
      ; lookup_sorted : ('f, 'bool) Opt.t Lookup_sorted_vec.t
      ; runtime_lookup_table : ('f, 'bool) Opt.t
      ; runtime_lookup_table_selector : ('f, 'bool) Opt.t
      ; xor_lookup_selector : ('f, 'bool) Opt.t
      ; lookup_gate_lookup_selector : ('f, 'bool) Opt.t
      ; range_check_lookup_selector : ('f, 'bool) Opt.t
      ; foreign_field_mul_lookup_selector : ('f, 'bool) Opt.t
      }
    [@@deriving hlist, fields]

    let map (type bool a b)
        ({ w
         ; coefficients
         ; z
         ; s
         ; generic_selector
         ; poseidon_selector
         ; complete_add_selector
         ; mul_selector
         ; emul_selector
         ; endomul_scalar_selector
         ; range_check0_selector
         ; range_check1_selector
         ; foreign_field_add_selector
         ; foreign_field_mul_selector
         ; xor_selector
         ; rot_selector
         ; lookup_aggregation
         ; lookup_table
         ; lookup_sorted
         ; runtime_lookup_table
         ; runtime_lookup_table_selector
         ; xor_lookup_selector
         ; lookup_gate_lookup_selector
         ; range_check_lookup_selector
         ; foreign_field_mul_lookup_selector
         } :
          (a, bool) t ) ~(f : a -> b) : (b, bool) t =
      { w = Vector.map w ~f
      ; coefficients = Vector.map coefficients ~f
      ; z = f z
      ; s = Vector.map s ~f
      ; generic_selector = f generic_selector
      ; poseidon_selector = f poseidon_selector
      ; complete_add_selector = f complete_add_selector
      ; mul_selector = f mul_selector
      ; emul_selector = f emul_selector
      ; endomul_scalar_selector = f endomul_scalar_selector
      ; range_check0_selector = Opt.map ~f range_check0_selector
      ; range_check1_selector = Opt.map ~f range_check1_selector
      ; foreign_field_add_selector = Opt.map ~f foreign_field_add_selector
      ; foreign_field_mul_selector = Opt.map ~f foreign_field_mul_selector
      ; xor_selector = Opt.map ~f xor_selector
      ; rot_selector = Opt.map ~f rot_selector
      ; lookup_aggregation = Opt.map ~f lookup_aggregation
      ; lookup_table = Opt.map ~f lookup_table
      ; lookup_sorted = Vector.map ~f:(Opt.map ~f) lookup_sorted
      ; runtime_lookup_table = Opt.map ~f runtime_lookup_table
      ; runtime_lookup_table_selector = Opt.map ~f runtime_lookup_table_selector
      ; xor_lookup_selector = Opt.map ~f xor_lookup_selector
      ; lookup_gate_lookup_selector = Opt.map ~f lookup_gate_lookup_selector
      ; range_check_lookup_selector = Opt.map ~f range_check_lookup_selector
      ; foreign_field_mul_lookup_selector =
          Opt.map ~f foreign_field_mul_lookup_selector
      }

    let to_list
        { w
        ; coefficients
        ; z
        ; s
        ; generic_selector
        ; poseidon_selector
        ; complete_add_selector
        ; mul_selector
        ; emul_selector
        ; endomul_scalar_selector
        ; range_check0_selector
        ; range_check1_selector
        ; foreign_field_add_selector
        ; foreign_field_mul_selector
        ; xor_selector
        ; rot_selector
        ; lookup_aggregation
        ; lookup_table
        ; lookup_sorted
        ; runtime_lookup_table
        ; runtime_lookup_table_selector
        ; xor_lookup_selector
        ; lookup_gate_lookup_selector
        ; range_check_lookup_selector
        ; foreign_field_mul_lookup_selector
        } =
      let some x = Opt.Some x in
      let always_present =
        List.map ~f:some
          ( [ z
            ; generic_selector
            ; poseidon_selector
            ; complete_add_selector
            ; mul_selector
            ; emul_selector
            ; endomul_scalar_selector
            ]
          @ Vector.to_list w
          @ Vector.to_list coefficients
          @ Vector.to_list s )
      in
      let optional_gates =
        [ range_check0_selector
        ; range_check1_selector
        ; foreign_field_add_selector
        ; foreign_field_mul_selector
        ; xor_selector
        ; rot_selector
        ]
      in
      always_present @ optional_gates
      @ Vector.to_list lookup_sorted
      @ [ lookup_aggregation
        ; lookup_table
        ; runtime_lookup_table
        ; runtime_lookup_table_selector
        ; xor_lookup_selector
        ; lookup_gate_lookup_selector
        ; range_check_lookup_selector
        ; foreign_field_mul_lookup_selector
        ]

    let to_absorption_sequence
        { w
        ; coefficients
        ; z
        ; s
        ; generic_selector
        ; poseidon_selector
        ; complete_add_selector
        ; mul_selector
        ; emul_selector
        ; endomul_scalar_selector
        ; range_check0_selector
        ; range_check1_selector
        ; foreign_field_add_selector
        ; foreign_field_mul_selector
        ; xor_selector
        ; rot_selector
        ; lookup_aggregation
        ; lookup_table
        ; lookup_sorted
        ; runtime_lookup_table
        ; runtime_lookup_table_selector
        ; xor_lookup_selector
        ; lookup_gate_lookup_selector
        ; range_check_lookup_selector
        ; foreign_field_mul_lookup_selector
        } : _ Opt.Early_stop_sequence.t =
      let always_present =
        [ z
        ; generic_selector
        ; poseidon_selector
        ; complete_add_selector
        ; mul_selector
        ; emul_selector
        ; endomul_scalar_selector
        ]
        @ Vector.to_list w
        @ Vector.to_list coefficients
        @ Vector.to_list s
      in
      let optional_gates =
        [ range_check0_selector
        ; range_check1_selector
        ; foreign_field_add_selector
        ; foreign_field_mul_selector
        ; xor_selector
        ; rot_selector
        ; lookup_aggregation
        ; lookup_table
        ]
      in
      let some x = Opt.Some x in
      List.map ~f:some always_present
      @ optional_gates
      @ Vector.to_list lookup_sorted
      @ [ runtime_lookup_table
        ; runtime_lookup_table_selector
        ; xor_lookup_selector
        ; lookup_gate_lookup_selector
        ; range_check_lookup_selector
        ; foreign_field_mul_lookup_selector
        ]
  end

  let to_in_circuit (type bool a)
      ({ w
       ; coefficients
       ; z
       ; s
       ; generic_selector
       ; poseidon_selector
       ; complete_add_selector
       ; mul_selector
       ; emul_selector
       ; endomul_scalar_selector
       ; range_check0_selector
       ; range_check1_selector
       ; foreign_field_add_selector
       ; foreign_field_mul_selector
       ; xor_selector
       ; rot_selector
       ; lookup_aggregation
       ; lookup_table
       ; lookup_sorted
       ; runtime_lookup_table
       ; runtime_lookup_table_selector
       ; xor_lookup_selector
       ; lookup_gate_lookup_selector
       ; range_check_lookup_selector
       ; foreign_field_mul_lookup_selector
       } :
        a t ) : (a, bool) In_circuit.t =
    { w
    ; coefficients
    ; z
    ; s
    ; generic_selector
    ; poseidon_selector
    ; complete_add_selector
    ; mul_selector
    ; emul_selector
    ; endomul_scalar_selector
    ; range_check0_selector = Opt.of_option range_check0_selector
    ; range_check1_selector = Opt.of_option range_check1_selector
    ; foreign_field_add_selector = Opt.of_option foreign_field_add_selector
    ; foreign_field_mul_selector = Opt.of_option foreign_field_mul_selector
    ; xor_selector = Opt.of_option xor_selector
    ; rot_selector = Opt.of_option rot_selector
    ; lookup_aggregation = Opt.of_option lookup_aggregation
    ; lookup_table = Opt.of_option lookup_table
    ; lookup_sorted = Vector.map ~f:Opt.of_option lookup_sorted
    ; runtime_lookup_table = Opt.of_option runtime_lookup_table
    ; runtime_lookup_table_selector =
        Opt.of_option runtime_lookup_table_selector
    ; xor_lookup_selector = Opt.of_option xor_lookup_selector
    ; lookup_gate_lookup_selector = Opt.of_option lookup_gate_lookup_selector
    ; range_check_lookup_selector = Opt.of_option range_check_lookup_selector
    ; foreign_field_mul_lookup_selector =
        Opt.of_option foreign_field_mul_lookup_selector
    }

  let map (type a b)
      ({ w
       ; coefficients
       ; z
       ; s
       ; generic_selector
       ; poseidon_selector
       ; complete_add_selector
       ; mul_selector
       ; emul_selector
       ; endomul_scalar_selector
       ; range_check0_selector
       ; range_check1_selector
       ; foreign_field_add_selector
       ; foreign_field_mul_selector
       ; xor_selector
       ; rot_selector
       ; lookup_aggregation
       ; lookup_table
       ; lookup_sorted
       ; runtime_lookup_table
       ; runtime_lookup_table_selector
       ; xor_lookup_selector
       ; lookup_gate_lookup_selector
       ; range_check_lookup_selector
       ; foreign_field_mul_lookup_selector
       } :
        a t ) ~(f : a -> b) : b t =
    { w = Vector.map w ~f
    ; coefficients = Vector.map coefficients ~f
    ; z = f z
    ; s = Vector.map s ~f
    ; generic_selector = f generic_selector
    ; poseidon_selector = f poseidon_selector
    ; complete_add_selector = f complete_add_selector
    ; mul_selector = f mul_selector
    ; emul_selector = f emul_selector
    ; endomul_scalar_selector = f endomul_scalar_selector
    ; range_check0_selector = Option.map ~f range_check0_selector
    ; range_check1_selector = Option.map ~f range_check1_selector
    ; foreign_field_add_selector = Option.map ~f foreign_field_add_selector
    ; foreign_field_mul_selector = Option.map ~f foreign_field_mul_selector
    ; xor_selector = Option.map ~f xor_selector
    ; rot_selector = Option.map ~f rot_selector
    ; lookup_aggregation = Option.map ~f lookup_aggregation
    ; lookup_table = Option.map ~f lookup_table
    ; lookup_sorted = Vector.map ~f:(Option.map ~f) lookup_sorted
    ; runtime_lookup_table = Option.map ~f runtime_lookup_table
    ; runtime_lookup_table_selector =
        Option.map ~f runtime_lookup_table_selector
    ; xor_lookup_selector = Option.map ~f xor_lookup_selector
    ; lookup_gate_lookup_selector = Option.map ~f lookup_gate_lookup_selector
    ; range_check_lookup_selector = Option.map ~f range_check_lookup_selector
    ; foreign_field_mul_lookup_selector =
        Option.map ~f foreign_field_mul_lookup_selector
    }

  let map2 (type a b c) (t1 : a t) (t2 : b t) ~(f : a -> b -> c) : c t =
    { w = Vector.map2 t1.w t2.w ~f
    ; coefficients = Vector.map2 t1.coefficients t2.coefficients ~f
    ; z = f t1.z t2.z
    ; s = Vector.map2 t1.s t2.s ~f
    ; generic_selector = f t1.generic_selector t2.generic_selector
    ; poseidon_selector = f t1.poseidon_selector t2.poseidon_selector
    ; complete_add_selector =
        f t1.complete_add_selector t2.complete_add_selector
    ; mul_selector = f t1.mul_selector t2.mul_selector
    ; emul_selector = f t1.emul_selector t2.emul_selector
    ; endomul_scalar_selector =
        f t1.endomul_scalar_selector t2.endomul_scalar_selector
    ; range_check0_selector =
        Option.map2 ~f t1.range_check0_selector t2.range_check0_selector
    ; range_check1_selector =
        Option.map2 ~f t1.range_check1_selector t2.range_check1_selector
    ; foreign_field_add_selector =
        Option.map2 ~f t1.foreign_field_add_selector
          t2.foreign_field_add_selector
    ; foreign_field_mul_selector =
        Option.map2 ~f t1.foreign_field_mul_selector
          t2.foreign_field_mul_selector
    ; xor_selector = Option.map2 ~f t1.xor_selector t2.xor_selector
    ; rot_selector = Option.map2 ~f t1.rot_selector t2.rot_selector
    ; lookup_aggregation =
        Option.map2 ~f t1.lookup_aggregation t2.lookup_aggregation
    ; lookup_table = Option.map2 ~f t1.lookup_table t2.lookup_table
    ; lookup_sorted =
        Vector.map2 ~f:(Option.map2 ~f) t1.lookup_sorted t2.lookup_sorted
    ; runtime_lookup_table =
        Option.map2 ~f t1.runtime_lookup_table t2.runtime_lookup_table
    ; runtime_lookup_table_selector =
        Option.map2 ~f t1.runtime_lookup_table_selector
          t2.runtime_lookup_table_selector
    ; xor_lookup_selector =
        Option.map2 ~f t1.xor_lookup_selector t2.xor_lookup_selector
    ; lookup_gate_lookup_selector =
        Option.map2 ~f t1.lookup_gate_lookup_selector
          t2.lookup_gate_lookup_selector
    ; range_check_lookup_selector =
        Option.map2 ~f t1.range_check_lookup_selector
          t2.range_check_lookup_selector
    ; foreign_field_mul_lookup_selector =
        Option.map2 ~f t1.foreign_field_mul_lookup_selector
          t2.foreign_field_mul_lookup_selector
    }

  (*
      This is in the same order as the evaluations in the opening proof:
     added later:
     - old sg polynomials
     - public input polynomial
     - ft
     here:
     - z
     - generic selector
     - poseidon selector
     - complete_add_selector
     - mul_selector
     - emul_selector
     - endomul_scalar_selector
     - w (witness columns)
     - coefficients
     - s (sigma columns)

     then optionally:
     - lookup sorted
     - lookup aggreg
     - lookup table
     - lookup runtime
  *)

  let to_list
      { w
      ; coefficients
      ; z
      ; s
      ; generic_selector
      ; poseidon_selector
      ; complete_add_selector
      ; mul_selector
      ; emul_selector
      ; endomul_scalar_selector
      ; range_check0_selector
      ; range_check1_selector
      ; foreign_field_add_selector
      ; foreign_field_mul_selector
      ; xor_selector
      ; rot_selector
      ; lookup_aggregation
      ; lookup_table
      ; lookup_sorted
      ; runtime_lookup_table
      ; runtime_lookup_table_selector
      ; xor_lookup_selector
      ; lookup_gate_lookup_selector
      ; range_check_lookup_selector
      ; foreign_field_mul_lookup_selector
      } =
    let always_present =
      [ z
      ; generic_selector
      ; poseidon_selector
      ; complete_add_selector
      ; mul_selector
      ; emul_selector
      ; endomul_scalar_selector
      ]
      @ Vector.to_list w
      @ Vector.to_list coefficients
      @ Vector.to_list s
    in
    let optional_gates =
      List.filter_map ~f:Fn.id
        [ range_check0_selector
        ; range_check1_selector
        ; foreign_field_add_selector
        ; foreign_field_mul_selector
        ; xor_selector
        ; rot_selector
        ]
    in
    always_present @ optional_gates
    @ List.filter_map ~f:Fn.id (Vector.to_list lookup_sorted)
    @ List.filter_map ~f:Fn.id
        [ lookup_aggregation
        ; lookup_table
        ; runtime_lookup_table
        ; runtime_lookup_table_selector
        ; xor_lookup_selector
        ; lookup_gate_lookup_selector
        ; range_check_lookup_selector
        ; foreign_field_mul_lookup_selector
        ]

  let typ (type f a_var a)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      ~dummy e (feature_flags : _ Features.t) :
      ((a_var, Impl.Boolean.var) In_circuit.t, a t, f) Snarky_backendless.Typ.t
      =
    let open Impl in
    let opt flag = Opt.typ Impl.Boolean.typ flag e ~dummy in
    let uses_lookup =
      let { Features.range_check0
          ; range_check1
          ; foreign_field_add = _ (* Doesn't use lookup *)
          ; foreign_field_mul
          ; xor
          ; rot
          ; lookup
          ; runtime_tables = _ (* Fixme *)
          } =
        feature_flags
      in
      Array.reduce_exn ~f:Opt.Flag.( ||| )
        [| range_check0; range_check1; foreign_field_mul; xor; rot; lookup |]
    in
    let lookup_sorted =
      match uses_lookup with
      | Opt.Flag.No ->
          Opt.Flag.No
      | Yes | Maybe ->
          Opt.Flag.Maybe
    in
    Typ.of_hlistable
      [ Vector.typ e Columns.n
      ; Vector.typ e Columns.n
      ; e
      ; Vector.typ e Permuts_minus_1.n
      ; e
      ; e
      ; e
      ; e
      ; e
      ; e
      ; opt feature_flags.range_check0
      ; opt feature_flags.range_check1
      ; opt feature_flags.foreign_field_add
      ; opt feature_flags.foreign_field_mul
      ; opt feature_flags.xor
      ; opt feature_flags.rot
      ; opt uses_lookup
      ; opt uses_lookup
      ; Vector.typ (opt lookup_sorted) Nat.N5.n (* TODO: Fixme *)
      ; opt feature_flags.runtime_tables
      ; opt feature_flags.runtime_tables
      ; opt feature_flags.xor
      ; opt feature_flags.lookup
      ; opt
          Opt.Flag.(
            feature_flags.range_check0 ||| feature_flags.range_check1
            ||| feature_flags.rot)
        (* TODO: This logic does not belong here. *)
      ; opt feature_flags.foreign_field_mul
      ]
      ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module All_evals = struct
  module With_public_input = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('f, 'f_multi) t =
          { public_input : 'f; evals : 'f_multi Evals.Stable.V2.t }
        [@@deriving sexp, compare, yojson, hash, equal, hlist]
      end
    end]

    module In_circuit = struct
      type ('f, 'f_multi, 'bool) t =
        { public_input : 'f; evals : ('f_multi, 'bool) Evals.In_circuit.t }
      [@@deriving hlist]

      let factor (type f f_multi bool)
          ({ public_input = p1, p2; evals } : (f * f, f_multi * f_multi, bool) t)
          : (f, f_multi, bool) t Tuple_lib.Double.t =
        ( { evals = Evals.In_circuit.map ~f:fst evals; public_input = p1 }
        , { evals = Evals.In_circuit.map ~f:snd evals; public_input = p2 } )
    end

    let map (type a1 a2 b1 b2) (t : (a1, a2) t) ~(f1 : a1 -> b1) ~(f2 : a2 -> b2)
        : (b1, b2) t =
      { public_input = f1 t.public_input; evals = Evals.map ~f:f2 t.evals }

    let typ impl feature_flags f f_multi ~dummy =
      let evals = Evals.typ impl f_multi feature_flags ~dummy in
      let open Snarky_backendless.Typ in
      of_hlistable [ f; evals ] ~var_to_hlist:In_circuit.to_hlist
        ~var_of_hlist:In_circuit.of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  [@@@warning "-4"]

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('f, 'f_multi) t =
        { evals : ('f * 'f, 'f_multi * 'f_multi) With_public_input.Stable.V1.t
        ; ft_eval1 : 'f
        }
      [@@deriving sexp, compare, yojson, hash, equal, hlist]
    end
  end]

  module In_circuit = struct
    type ('f, 'f_multi, 'bool) t =
      { evals :
          ('f * 'f, 'f_multi * 'f_multi, 'bool) With_public_input.In_circuit.t
      ; ft_eval1 : 'f
      }
    [@@deriving hlist]
  end

  let map (type a1 a2 b1 b2) (t : (a1, a2) t) ~(f1 : a1 -> b1) ~(f2 : a2 -> b2)
      : (b1, b2) t =
    { evals =
        With_public_input.map t.evals
          ~f1:(Tuple_lib.Double.map ~f:f1)
          ~f2:(Tuple_lib.Double.map ~f:f2)
    ; ft_eval1 = f1 t.ft_eval1
    }

  let typ (type f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      feature_flags =
    let open Impl.Typ in
    let single = array ~length:1 field in
    let evals =
      With_public_input.typ
        (module Impl)
        feature_flags (tuple2 field field) (tuple2 single single)
        ~dummy:Impl.Field.Constant.([| zero |], [| zero |])
    in
    of_hlistable [ evals; Impl.Field.typ ] ~var_to_hlist:In_circuit.to_hlist
      ~var_of_hlist:In_circuit.of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Openings = struct
  [@@@warning "-4"] (* Deals with the 2 sexp-deriving types below *)

  module Bulletproof = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('g, 'fq) t =
          { lr : ('g * 'g) array
          ; z_1 : 'fq
          ; z_2 : 'fq
          ; delta : 'g
          ; challenge_polynomial_commitment : 'g
          }
        [@@deriving sexp, compare, yojson, hash, equal, hlist]
      end
    end]

    let typ fq g ~length =
      let open Snarky_backendless.Typ in
      of_hlistable
        [ array ~length (g * g); fq; fq; g; g ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('g, 'fq, 'fqv) t =
        { proof : ('g, 'fq) Bulletproof.Stable.V1.t
        ; evals : ('fqv * 'fqv) Evals.Stable.V2.t
        ; ft_eval1 : 'fq
        }
      [@@deriving sexp, compare, yojson, hash, equal, hlist]
    end
  end]
end

module Poly_comm = struct
  module With_degree_bound = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'g_opt t = { unshifted : 'g_opt array; shifted : 'g_opt }
        [@@deriving sexp, compare, yojson, hlist, hash, equal]
      end
    end]

    let padded_array_typ0 = padded_array_typ

    let typ (type f g g_var bool_var)
        (g : (g_var, g, f) Snarky_backendless.Typ.t) ~length
        ~dummy_group_element
        ~(bool : (bool_var, bool, f) Snarky_backendless.Typ.t) :
        ((bool_var * g_var) t, g Or_infinity.t t, f) Snarky_backendless.Typ.t =
      let open Snarky_backendless.Typ in
      let g_inf =
        transport (tuple2 bool g)
          ~there:(function
            | Or_infinity.Infinity ->
                (false, dummy_group_element)
            | Finite x ->
                (true, x) )
          ~back:(fun (b, x) -> if b then Infinity else Finite x)
      in
      let arr = padded_array_typ0 ~length ~dummy:Or_infinity.Infinity g_inf in
      of_hlistable [ arr; g_inf ] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
  end

  module Without_degree_bound = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'g t = 'g array [@@deriving sexp, compare, yojson, hash, equal]
      end
    end]
  end
end

module Messages = struct
  open Poly_comm

  module Poly = struct
    type ('w, 'z, 't) t = { w : 'w; z : 'z; t : 't }
    [@@deriving sexp, compare, yojson, fields, hash, equal, hlist]
  end

  module Lookup = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'g t = { sorted : 'g array; aggreg : 'g; runtime : 'g option }
        [@@deriving fields, sexp, compare, yojson, hash, equal, hlist]
      end
    end]

    module In_circuit = struct
      type ('g, 'bool) t =
        { sorted : 'g array; aggreg : 'g; runtime : ('g, 'bool) Opt.t }
      [@@deriving hlist]
    end

    let sorted_length = 5

    let dummy ~runtime_tables z =
      { aggreg = z
      ; sorted = Array.create ~len:sorted_length z
      ; runtime = Option.some_if runtime_tables z
      }

    let typ bool_typ e ~runtime_tables ~dummy =
      Snarky_backendless.Typ.of_hlistable
        [ Snarky_backendless.Typ.array ~length:sorted_length e
        ; e
        ; Opt.typ bool_typ runtime_tables e ~dummy
        ]
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
        ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist

    let opt_typ bool_typ ~(lookup : Opt.Flag.t) ~(runtime_tables : Opt.Flag.t)
        ~dummy:z elt =
      Opt.typ bool_typ lookup
        ~dummy:
          (dummy z ~runtime_tables:Opt.Flag.(not (equal runtime_tables No)))
        (typ bool_typ ~runtime_tables ~dummy:z elt)
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'g t =
        { w_comm : 'g Without_degree_bound.Stable.V1.t Columns_vec.Stable.V1.t
        ; z_comm : 'g Without_degree_bound.Stable.V1.t
        ; t_comm : 'g Without_degree_bound.Stable.V1.t
        ; lookup : 'g Without_degree_bound.Stable.V1.t Lookup.Stable.V1.t option
        }
      [@@deriving sexp, compare, yojson, fields, hash, equal, hlist]
    end
  end]

  module In_circuit = struct
    type ('g, 'bool) t =
      { w_comm : 'g Without_degree_bound.t Columns_vec.t
      ; z_comm : 'g Without_degree_bound.t
      ; t_comm : 'g Without_degree_bound.t
      ; lookup :
          (('g Without_degree_bound.t, 'bool) Lookup.In_circuit.t, 'bool) Opt.t
      }
    [@@deriving hlist, fields]
  end

  let typ (type n f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) g
      ({ lookup; runtime_tables; _ } : Opt.Flag.t Features.t) ~dummy
      ~(commitment_lengths : (((int, n) Vector.t as 'v), int, int) Poly.t) ~bool
      =
    let open Snarky_backendless.Typ in
    let { Poly.w = w_lens; z; t } = commitment_lengths in
    let array ~length elt = padded_array_typ ~dummy ~length elt in
    let wo n = array ~length:(Vector.reduce_exn n ~f:Int.max) g in
    let _w n =
      With_degree_bound.typ g
        ~length:(Vector.reduce_exn n ~f:Int.max)
        ~dummy_group_element:dummy ~bool
    in
    let lookup =
      Lookup.opt_typ Impl.Boolean.typ ~lookup ~runtime_tables ~dummy:[| dummy |]
        (wo [ 1 ])
    in
    of_hlistable
      [ Vector.typ (wo w_lens) Columns.n; wo [ z ]; wo [ t ]; lookup ]
      ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Proof = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('g, 'fq, 'fqv) t =
        { messages : 'g Messages.Stable.V2.t
        ; openings : ('g, 'fq, 'fqv) Openings.Stable.V2.t
        }
      [@@deriving sexp, compare, yojson, hash, equal]
    end
  end]
end

module Shifts = struct
  open Core_kernel

  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'field t = 'field array [@@deriving sexp, compare, yojson, equal]
    end
  end]
end
