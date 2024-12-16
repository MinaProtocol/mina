open Core_kernel
module Step_impl = Kimchi_pasta_snarky_backend.Step_impl
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

let padded_array_typ ~length ~dummy elt =
  Step_impl.Typ.array ~length elt
  |> Step_impl.Typ.transport
       ~there:(fun a ->
         let n = Array.length a in
         if n > length then failwithf "Expected %d <= %d" n length () ;
         Array.append a (Array.create ~len:(length - n) dummy) )
       ~back:Fn.id

let wrap_padded_array_typ ~length ~dummy elt =
  Wrap_impl.Typ.array ~length elt
  |> Wrap_impl.Typ.transport
       ~there:(fun a ->
         let n = Array.length a in
         if n > length then failwithf "Expected %d <= %d" n length () ;
         Array.append a (Array.create ~len:(length - n) dummy) )
       ~back:Fn.id

let hash_fold_array f s x = hash_fold_list f s (Array.to_list x)

module Columns = Plonkish_prelude.Nat.N15
module Columns_vec = Plonkish_prelude.Vector.Vector_15
module Permuts_minus_1 = Plonkish_prelude.Nat.N6
module Permuts_minus_1_vec = Plonkish_prelude.Vector.Vector_6
module Permuts = Plonkish_prelude.Nat.N7
module Permuts_vec = Plonkish_prelude.Vector.Vector_7
module Lookup_sorted_minus_1 = Plonkish_prelude.Nat.N4
module Lookup_sorted_minus_1_vec = Plonkish_prelude.Vector.Vector_4
module Lookup_sorted = Plonkish_prelude.Nat.N5
module Lookup_sorted_vec = Plonkish_prelude.Vector.Vector_5

module Features = struct
  module Full = struct
    type 'bool t =
      { range_check0 : 'bool
      ; range_check1 : 'bool
      ; foreign_field_add : 'bool
      ; foreign_field_mul : 'bool
      ; xor : 'bool
      ; rot : 'bool
      ; lookup : 'bool
      ; runtime_tables : 'bool
      ; uses_lookups : 'bool
      ; table_width_at_least_1 : 'bool
      ; table_width_at_least_2 : 'bool
      ; table_width_3 : 'bool
      ; lookups_per_row_3 : 'bool
      ; lookups_per_row_4 : 'bool
      ; lookup_pattern_xor : 'bool
      ; lookup_pattern_range_check : 'bool
      }
    [@@deriving sexp, compare, yojson, hash, equal, hlist]

    let get_feature_flag (feature_flags : _ t)
        (feature : Kimchi_types.feature_flag) =
      match feature with
      | RangeCheck0 ->
          Some feature_flags.range_check0
      | RangeCheck1 ->
          Some feature_flags.range_check1
      | ForeignFieldAdd ->
          Some feature_flags.foreign_field_add
      | ForeignFieldMul ->
          Some feature_flags.foreign_field_mul
      | Xor ->
          Some feature_flags.xor
      | Rot ->
          Some feature_flags.rot
      | LookupTables ->
          Some feature_flags.uses_lookups
      | RuntimeLookupTables ->
          Some feature_flags.runtime_tables
      | TableWidth 3 ->
          Some feature_flags.table_width_3
      | TableWidth 2 ->
          Some feature_flags.table_width_at_least_2
      | TableWidth i when i <= 1 ->
          Some feature_flags.table_width_at_least_1
      | TableWidth _ ->
          None
      | LookupsPerRow 4 ->
          Some feature_flags.lookups_per_row_4
      | LookupsPerRow i when i <= 3 ->
          Some feature_flags.lookups_per_row_3
      | LookupsPerRow _ ->
          None
      | LookupPattern Lookup ->
          Some feature_flags.lookup
      | LookupPattern Xor ->
          Some feature_flags.lookup_pattern_xor
      | LookupPattern RangeCheck ->
          Some feature_flags.lookup_pattern_range_check
      | LookupPattern ForeignFieldMul ->
          Some feature_flags.foreign_field_mul

    let map
        { range_check0
        ; range_check1
        ; foreign_field_add
        ; foreign_field_mul
        ; rot
        ; xor
        ; lookup
        ; runtime_tables
        ; uses_lookups
        ; table_width_at_least_1
        ; table_width_at_least_2
        ; table_width_3
        ; lookups_per_row_3
        ; lookups_per_row_4
        ; lookup_pattern_xor
        ; lookup_pattern_range_check
        } ~f =
      { range_check0 = f range_check0
      ; range_check1 = f range_check1
      ; foreign_field_add = f foreign_field_add
      ; foreign_field_mul = f foreign_field_mul
      ; xor = f xor
      ; rot = f rot
      ; lookup = f lookup
      ; runtime_tables = f runtime_tables
      ; uses_lookups = f uses_lookups
      ; table_width_at_least_1 = f table_width_at_least_1
      ; table_width_at_least_2 = f table_width_at_least_2
      ; table_width_3 = f table_width_3
      ; lookups_per_row_3 = f lookups_per_row_3
      ; lookups_per_row_4 = f lookups_per_row_4
      ; lookup_pattern_xor = f lookup_pattern_xor
      ; lookup_pattern_range_check = f lookup_pattern_range_check
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
      ; uses_lookups = f x1.uses_lookups x2.uses_lookups
      ; table_width_at_least_1 =
          f x1.table_width_at_least_1 x2.table_width_at_least_1
      ; table_width_at_least_2 =
          f x1.table_width_at_least_2 x2.table_width_at_least_2
      ; table_width_3 = f x1.table_width_3 x2.table_width_3
      ; lookups_per_row_3 = f x1.lookups_per_row_3 x2.lookups_per_row_3
      ; lookups_per_row_4 = f x1.lookups_per_row_4 x2.lookups_per_row_4
      ; lookup_pattern_xor = f x1.lookup_pattern_xor x2.lookup_pattern_xor
      ; lookup_pattern_range_check =
          f x1.lookup_pattern_range_check x2.lookup_pattern_range_check
      }

    let none =
      { range_check0 = Plonkish_prelude.Opt.Flag.No
      ; range_check1 = Plonkish_prelude.Opt.Flag.No
      ; foreign_field_add = Plonkish_prelude.Opt.Flag.No
      ; foreign_field_mul = Plonkish_prelude.Opt.Flag.No
      ; xor = Plonkish_prelude.Opt.Flag.No
      ; rot = Plonkish_prelude.Opt.Flag.No
      ; lookup = Plonkish_prelude.Opt.Flag.No
      ; runtime_tables = Plonkish_prelude.Opt.Flag.No
      ; uses_lookups = Plonkish_prelude.Opt.Flag.No
      ; table_width_at_least_1 = Plonkish_prelude.Opt.Flag.No
      ; table_width_at_least_2 = Plonkish_prelude.Opt.Flag.No
      ; table_width_3 = Plonkish_prelude.Opt.Flag.No
      ; lookups_per_row_3 = Plonkish_prelude.Opt.Flag.No
      ; lookups_per_row_4 = Plonkish_prelude.Opt.Flag.No
      ; lookup_pattern_xor = Plonkish_prelude.Opt.Flag.No
      ; lookup_pattern_range_check = Plonkish_prelude.Opt.Flag.No
      }

    let maybe =
      { range_check0 = Plonkish_prelude.Opt.Flag.Maybe
      ; range_check1 = Plonkish_prelude.Opt.Flag.Maybe
      ; foreign_field_add = Plonkish_prelude.Opt.Flag.Maybe
      ; foreign_field_mul = Plonkish_prelude.Opt.Flag.Maybe
      ; xor = Plonkish_prelude.Opt.Flag.Maybe
      ; rot = Plonkish_prelude.Opt.Flag.Maybe
      ; lookup = Plonkish_prelude.Opt.Flag.Maybe
      ; runtime_tables = Plonkish_prelude.Opt.Flag.Maybe
      ; uses_lookups = Plonkish_prelude.Opt.Flag.Maybe
      ; table_width_at_least_1 = Plonkish_prelude.Opt.Flag.Maybe
      ; table_width_at_least_2 = Plonkish_prelude.Opt.Flag.Maybe
      ; table_width_3 = Plonkish_prelude.Opt.Flag.Maybe
      ; lookups_per_row_3 = Plonkish_prelude.Opt.Flag.Maybe
      ; lookups_per_row_4 = Plonkish_prelude.Opt.Flag.Maybe
      ; lookup_pattern_xor = Plonkish_prelude.Opt.Flag.Maybe
      ; lookup_pattern_range_check = Plonkish_prelude.Opt.Flag.Maybe
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
      ; uses_lookups = false
      ; table_width_at_least_1 = false
      ; table_width_at_least_2 = false
      ; table_width_3 = false
      ; lookups_per_row_3 = false
      ; lookups_per_row_4 = false
      ; lookup_pattern_xor = false
      ; lookup_pattern_range_check = false
      }
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'bool t =
            'bool Mina_wire_types.Pickles_types.Plonk_types.Features.V1.t =
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

  let of_full
      ({ range_check0
       ; range_check1
       ; foreign_field_add
       ; foreign_field_mul
       ; xor
       ; rot
       ; lookup
       ; runtime_tables
       ; uses_lookups = _
       ; table_width_at_least_1 = _
       ; table_width_at_least_2 = _
       ; table_width_3 = _
       ; lookups_per_row_3 = _
       ; lookups_per_row_4 = _
       ; lookup_pattern_xor = _
       ; lookup_pattern_range_check = _
       } :
        'bool Full.t ) =
    { range_check0
    ; range_check1
    ; foreign_field_add
    ; foreign_field_mul
    ; xor
    ; rot
    ; lookup
    ; runtime_tables
    }

  let to_full ~or_:( ||| ) ?(any = List.reduce_exn ~f:( ||| ))
      { range_check0
      ; range_check1
      ; foreign_field_add
      ; foreign_field_mul
      ; xor
      ; rot
      ; lookup
      ; runtime_tables
      } : _ Full.t =
    let lookup_pattern_range_check =
      (* RangeCheck, Rot gates use RangeCheck lookup pattern *)
      range_check0 ||| range_check1 ||| rot
    in
    let lookup_pattern_xor =
      (* Xor lookup pattern *)
      xor
    in
    (* Make sure these stay up-to-date with the layouts!! *)
    let table_width_3 =
      (* Xor have max_joint_size = 3 *)
      lookup_pattern_xor
    in
    let table_width_at_least_2 =
      (* Lookup has max_joint_size = 2 *)
      table_width_3 ||| lookup
    in
    let table_width_at_least_1 =
      (* RangeCheck, ForeignFieldMul have max_joint_size = 1 *)
      any
        [ table_width_at_least_2
        ; lookup_pattern_range_check
        ; foreign_field_mul
        ]
    in
    let lookups_per_row_4 =
      (* Xor, RangeCheckGate, ForeignFieldMul, have max_lookups_per_row = 4 *)
      any [ lookup_pattern_xor; lookup_pattern_range_check; foreign_field_mul ]
    in
    let lookups_per_row_3 =
      (* Lookup has max_lookups_per_row = 3 *)
      lookups_per_row_4 ||| lookup
    in
    { uses_lookups = lookups_per_row_3
    ; table_width_at_least_1
    ; table_width_at_least_2
    ; table_width_3
    ; lookups_per_row_3
    ; lookups_per_row_4
    ; lookup_pattern_xor
    ; lookup_pattern_range_check
    ; range_check0
    ; range_check1
    ; foreign_field_add
    ; foreign_field_mul
    ; xor
    ; rot
    ; lookup
    ; runtime_tables
    }

  type options = Plonkish_prelude.Opt.Flag.t t

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
      } : _ Plonkish_prelude.Hlist.HlistId.t =
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
        _ Plonkish_prelude.Hlist.HlistId.t ) =
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
    let module Impl = Step_impl in
    let constant (type var value) (typ : (var, value) Impl.Typ.t) (x : value) :
        var =
      let (Typ typ) = typ in
      let fields, aux = typ.value_to_fields x in
      let fields = Array.map ~f:(fun x -> Impl.Field.constant x) fields in
      typ.var_of_fields (fields, aux)
    in
    let constant_typ ~there value =
      let open Impl.Typ in
      unit
      |> transport ~there ~back:(fun () -> value)
      |> transport_var ~there:(fun _ -> ()) ~back:(fun () -> constant bool value)
    in
    let bool_typ_of_flag = function
      | Plonkish_prelude.Opt.Flag.Yes ->
          constant_typ
            ~there:(function true -> () | false -> assert false)
            true
      | Plonkish_prelude.Opt.Flag.No ->
          constant_typ
            ~there:(function false -> () | true -> assert false)
            false
      | Plonkish_prelude.Opt.Flag.Maybe ->
          bool
    in
    Impl.Typ.of_hlistable
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
    { range_check0 = Plonkish_prelude.Opt.Flag.No
    ; range_check1 = Plonkish_prelude.Opt.Flag.No
    ; foreign_field_add = Plonkish_prelude.Opt.Flag.No
    ; foreign_field_mul = Plonkish_prelude.Opt.Flag.No
    ; xor = Plonkish_prelude.Opt.Flag.No
    ; rot = Plonkish_prelude.Opt.Flag.No
    ; lookup = Plonkish_prelude.Opt.Flag.No
    ; runtime_tables = Plonkish_prelude.Opt.Flag.No
    }

  let maybe =
    { range_check0 = Plonkish_prelude.Opt.Flag.Maybe
    ; range_check1 = Plonkish_prelude.Opt.Flag.Maybe
    ; foreign_field_add = Plonkish_prelude.Opt.Flag.Maybe
    ; foreign_field_mul = Plonkish_prelude.Opt.Flag.Maybe
    ; xor = Plonkish_prelude.Opt.Flag.Maybe
    ; rot = Plonkish_prelude.Opt.Flag.Maybe
    ; lookup = Plonkish_prelude.Opt.Flag.Maybe
    ; runtime_tables = Plonkish_prelude.Opt.Flag.Maybe
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
      type 'a t = 'a Mina_wire_types.Pickles_types.Plonk_types.Evals.V2.t =
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

  (* NB: Equivalent checks are run in-circuit below. *)
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
    let lookups_per_row_4 =
      f.xor || range_check_lookup || f.foreign_field_mul
    in
    let lookups_per_row_3 = lookups_per_row_4 || f.lookup in
    let lookups_per_row_2 = lookups_per_row_3 in
    Array.reduce_exn ~f:( && )
      [| enable_if range_check0_selector f.range_check0
       ; enable_if range_check1_selector f.range_check1
       ; enable_if foreign_field_add_selector f.foreign_field_add
       ; enable_if foreign_field_mul_selector f.foreign_field_mul
       ; enable_if xor_selector f.xor
       ; enable_if rot_selector f.rot
       ; enable_if lookup_aggregation lookups_per_row_2
       ; enable_if lookup_table lookups_per_row_2
       ; Plonkish_prelude.Vector.foldi lookup_sorted ~init:true
           ~f:(fun i acc x ->
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
      @ Plonkish_prelude.Vector.to_list w
      @ Plonkish_prelude.Vector.to_list coefficients
      @ Plonkish_prelude.Vector.to_list s
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
    @ List.filter_map ~f:Fn.id (Plonkish_prelude.Vector.to_list lookup_sorted)
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
      ; range_check0_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; range_check1_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; foreign_field_add_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; foreign_field_mul_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; xor_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; rot_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; lookup_aggregation : ('f, 'bool) Plonkish_prelude.Opt.t
      ; lookup_table : ('f, 'bool) Plonkish_prelude.Opt.t
      ; lookup_sorted : ('f, 'bool) Plonkish_prelude.Opt.t Lookup_sorted_vec.t
      ; runtime_lookup_table : ('f, 'bool) Plonkish_prelude.Opt.t
      ; runtime_lookup_table_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; xor_lookup_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; lookup_gate_lookup_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; range_check_lookup_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; foreign_field_mul_lookup_selector : ('f, 'bool) Plonkish_prelude.Opt.t
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
      { w = Plonkish_prelude.Vector.map w ~f
      ; coefficients = Plonkish_prelude.Vector.map coefficients ~f
      ; z = f z
      ; s = Plonkish_prelude.Vector.map s ~f
      ; generic_selector = f generic_selector
      ; poseidon_selector = f poseidon_selector
      ; complete_add_selector = f complete_add_selector
      ; mul_selector = f mul_selector
      ; emul_selector = f emul_selector
      ; endomul_scalar_selector = f endomul_scalar_selector
      ; range_check0_selector =
          Plonkish_prelude.Opt.map ~f range_check0_selector
      ; range_check1_selector =
          Plonkish_prelude.Opt.map ~f range_check1_selector
      ; foreign_field_add_selector =
          Plonkish_prelude.Opt.map ~f foreign_field_add_selector
      ; foreign_field_mul_selector =
          Plonkish_prelude.Opt.map ~f foreign_field_mul_selector
      ; xor_selector = Plonkish_prelude.Opt.map ~f xor_selector
      ; rot_selector = Plonkish_prelude.Opt.map ~f rot_selector
      ; lookup_aggregation = Plonkish_prelude.Opt.map ~f lookup_aggregation
      ; lookup_table = Plonkish_prelude.Opt.map ~f lookup_table
      ; lookup_sorted =
          Plonkish_prelude.Vector.map
            ~f:(Plonkish_prelude.Opt.map ~f)
            lookup_sorted
      ; runtime_lookup_table = Plonkish_prelude.Opt.map ~f runtime_lookup_table
      ; runtime_lookup_table_selector =
          Plonkish_prelude.Opt.map ~f runtime_lookup_table_selector
      ; xor_lookup_selector = Plonkish_prelude.Opt.map ~f xor_lookup_selector
      ; lookup_gate_lookup_selector =
          Plonkish_prelude.Opt.map ~f lookup_gate_lookup_selector
      ; range_check_lookup_selector =
          Plonkish_prelude.Opt.map ~f range_check_lookup_selector
      ; foreign_field_mul_lookup_selector =
          Plonkish_prelude.Opt.map ~f foreign_field_mul_lookup_selector
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
      let always_present =
        List.map ~f:Plonkish_prelude.Opt.just
          ( [ z
            ; generic_selector
            ; poseidon_selector
            ; complete_add_selector
            ; mul_selector
            ; emul_selector
            ; endomul_scalar_selector
            ]
          @ Plonkish_prelude.Vector.to_list w
          @ Plonkish_prelude.Vector.to_list coefficients
          @ Plonkish_prelude.Vector.to_list s )
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
      @ Plonkish_prelude.Vector.to_list lookup_sorted
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
        } : _ Plonkish_prelude.Opt.Early_stop_sequence.t =
      let always_present =
        [ z
        ; generic_selector
        ; poseidon_selector
        ; complete_add_selector
        ; mul_selector
        ; emul_selector
        ; endomul_scalar_selector
        ]
        @ Plonkish_prelude.Vector.to_list w
        @ Plonkish_prelude.Vector.to_list coefficients
        @ Plonkish_prelude.Vector.to_list s
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

      List.map ~f:Plonkish_prelude.Opt.just always_present
      @ optional_gates
      @ Plonkish_prelude.Vector.to_list lookup_sorted
      @ [ runtime_lookup_table
        ; runtime_lookup_table_selector
        ; xor_lookup_selector
        ; lookup_gate_lookup_selector
        ; range_check_lookup_selector
        ; foreign_field_mul_lookup_selector
        ]

    (* NB: Equivalent checks are done out-of-circuit above. *)
    let validate_feature_flags ~true_ ~false_ ~or_:( ||| ) ~assert_equal
        ~feature_flags:(f : 'boolean Features.t)
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
      let opt_flag = function
        | Plonkish_prelude.Opt.Just _ ->
            true_
        | Plonkish_prelude.Opt.Maybe (b, _) ->
            b
        | Plonkish_prelude.Opt.Nothing ->
            false_
      in
      let enable_if x flag = assert_equal (opt_flag x) flag in
      let range_check_lookup = f.range_check0 ||| f.range_check1 ||| f.rot in
      let lookups_per_row_4 =
        f.xor ||| range_check_lookup ||| f.foreign_field_mul
      in
      let lookups_per_row_3 = lookups_per_row_4 ||| f.lookup in
      let lookups_per_row_2 = lookups_per_row_3 in
      enable_if range_check0_selector f.range_check0 ;
      enable_if range_check1_selector f.range_check1 ;
      enable_if foreign_field_add_selector f.foreign_field_add ;
      enable_if foreign_field_mul_selector f.foreign_field_mul ;
      enable_if xor_selector f.xor ;
      enable_if rot_selector f.rot ;
      enable_if lookup_aggregation lookups_per_row_2 ;
      enable_if lookup_table lookups_per_row_2 ;
      Plonkish_prelude.Vector.iteri lookup_sorted ~f:(fun i x ->
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
          enable_if x flag ) ;
      enable_if runtime_lookup_table f.runtime_tables ;
      enable_if runtime_lookup_table_selector f.runtime_tables ;
      enable_if xor_lookup_selector f.xor ;
      enable_if lookup_gate_lookup_selector f.lookup ;
      enable_if range_check_lookup_selector range_check_lookup ;
      enable_if foreign_field_mul_lookup_selector f.foreign_field_mul
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
    ; range_check0_selector =
        Plonkish_prelude.Opt.of_option range_check0_selector
    ; range_check1_selector =
        Plonkish_prelude.Opt.of_option range_check1_selector
    ; foreign_field_add_selector =
        Plonkish_prelude.Opt.of_option foreign_field_add_selector
    ; foreign_field_mul_selector =
        Plonkish_prelude.Opt.of_option foreign_field_mul_selector
    ; xor_selector = Plonkish_prelude.Opt.of_option xor_selector
    ; rot_selector = Plonkish_prelude.Opt.of_option rot_selector
    ; lookup_aggregation = Plonkish_prelude.Opt.of_option lookup_aggregation
    ; lookup_table = Plonkish_prelude.Opt.of_option lookup_table
    ; lookup_sorted =
        Plonkish_prelude.Vector.map ~f:Plonkish_prelude.Opt.of_option
          lookup_sorted
    ; runtime_lookup_table = Plonkish_prelude.Opt.of_option runtime_lookup_table
    ; runtime_lookup_table_selector =
        Plonkish_prelude.Opt.of_option runtime_lookup_table_selector
    ; xor_lookup_selector = Plonkish_prelude.Opt.of_option xor_lookup_selector
    ; lookup_gate_lookup_selector =
        Plonkish_prelude.Opt.of_option lookup_gate_lookup_selector
    ; range_check_lookup_selector =
        Plonkish_prelude.Opt.of_option range_check_lookup_selector
    ; foreign_field_mul_lookup_selector =
        Plonkish_prelude.Opt.of_option foreign_field_mul_lookup_selector
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
    { w = Plonkish_prelude.Vector.map w ~f
    ; coefficients = Plonkish_prelude.Vector.map coefficients ~f
    ; z = f z
    ; s = Plonkish_prelude.Vector.map s ~f
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
    ; lookup_sorted =
        Plonkish_prelude.Vector.map ~f:(Option.map ~f) lookup_sorted
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
    { w = Plonkish_prelude.Vector.map2 t1.w t2.w ~f
    ; coefficients =
        Plonkish_prelude.Vector.map2 t1.coefficients t2.coefficients ~f
    ; z = f t1.z t2.z
    ; s = Plonkish_prelude.Vector.map2 t1.s t2.s ~f
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
        Plonkish_prelude.Vector.map2 ~f:(Option.map2 ~f) t1.lookup_sorted
          t2.lookup_sorted
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
      @ Plonkish_prelude.Vector.to_list w
      @ Plonkish_prelude.Vector.to_list coefficients
      @ Plonkish_prelude.Vector.to_list s
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
    @ List.filter_map ~f:Fn.id (Plonkish_prelude.Vector.to_list lookup_sorted)
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

  let typ (type a_var a) ~dummy e
      ({ uses_lookups; lookups_per_row_3; lookups_per_row_4; _ } as
       feature_flags :
        _ Features.Full.t ) :
      ((a_var, Step_impl.Boolean.var) In_circuit.t, a t) Step_impl.Typ.t =
    let open Step_impl in
    let opt flag = Plonkish_prelude.Opt.typ flag e ~dummy in
    let lookup_sorted =
      let lookups_per_row_3 = opt lookups_per_row_3 in
      let lookups_per_row_4 = opt lookups_per_row_4 in
      Plonkish_prelude.Vector.typ'
        [ lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_4
        ]
    in
    Typ.of_hlistable
      [ Plonkish_prelude.Vector.typ e Columns.n
      ; Plonkish_prelude.Vector.typ e Columns.n
      ; e
      ; Plonkish_prelude.Vector.typ e Permuts_minus_1.n
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
      ; opt uses_lookups
      ; opt uses_lookups
      ; lookup_sorted
      ; opt feature_flags.runtime_tables
      ; opt feature_flags.runtime_tables
      ; opt feature_flags.lookup_pattern_xor
      ; opt feature_flags.lookup
      ; opt feature_flags.lookup_pattern_range_check
      ; opt feature_flags.foreign_field_mul
      ]
      ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let wrap_typ (type a_var a) ~dummy e
      ({ uses_lookups; lookups_per_row_3; lookups_per_row_4; _ } as
       feature_flags :
        _ Features.Full.t ) :
      ((a_var, Wrap_impl.Boolean.var) In_circuit.t, a t) Wrap_impl.Typ.t =
    let open Wrap_impl in
    let opt flag = Plonkish_prelude.Opt.wrap_typ flag e ~dummy in
    let lookup_sorted =
      let lookups_per_row_3 = opt lookups_per_row_3 in
      let lookups_per_row_4 = opt lookups_per_row_4 in
      Plonkish_prelude.Vector.wrap_typ'
        [ lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_4
        ]
    in
    Typ.of_hlistable
      [ Plonkish_prelude.Vector.wrap_typ e Columns.n
      ; Plonkish_prelude.Vector.wrap_typ e Columns.n
      ; e
      ; Plonkish_prelude.Vector.wrap_typ e Permuts_minus_1.n
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
      ; opt uses_lookups
      ; opt uses_lookups
      ; lookup_sorted
      ; opt feature_flags.runtime_tables
      ; opt feature_flags.runtime_tables
      ; opt feature_flags.lookup_pattern_xor
      ; opt feature_flags.lookup
      ; opt feature_flags.lookup_pattern_range_check
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
              ( 'f
              , 'f_multi )
              Mina_wire_types.Pickles_types.Plonk_types.All_evals
              .With_public_input
              .V1
              .t =
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

    let typ feature_flags f f_multi ~dummy =
      let evals = Evals.typ f_multi feature_flags ~dummy in
      let open Step_impl.Typ in
      of_hlistable [ f; evals ] ~var_to_hlist:In_circuit.to_hlist
        ~var_of_hlist:In_circuit.of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let wrap_typ feature_flags f f_multi ~dummy =
      let evals = Evals.wrap_typ f_multi feature_flags ~dummy in
      let open Wrap_impl.Typ in
      of_hlistable [ f; evals ] ~var_to_hlist:In_circuit.to_hlist
        ~var_of_hlist:In_circuit.of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  [@@@warning "-4"]

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type ('f, 'f_multi) t =
        { evals : ('f * 'f, 'f_multi * 'f_multi) With_public_input.Stable.V1.t
        ; ft_eval1 : 'f
        }
      [@@deriving sexp, compare, yojson, hash, equal, hlist]
    end
  end]

  type ('f, 'f_multi) t =
        ('f, 'f_multi) Mina_wire_types.Pickles_types.Plonk_types.All_evals.V1.t =
    { evals : ('f_multi * 'f_multi, 'f_multi * 'f_multi) With_public_input.t
    ; ft_eval1 : 'f
    }
  [@@deriving sexp, compare, yojson, hash, equal, hlist]

  module In_circuit = struct
    type ('f, 'f_multi, 'bool) t =
      { evals :
          ( 'f_multi * 'f_multi
          , 'f_multi * 'f_multi
          , 'bool )
          With_public_input.In_circuit.t
      ; ft_eval1 : 'f
      }
    [@@deriving hlist]
  end

  let map (type a1 a2 b1 b2) (t : (a1, a2) t) ~(f1 : a1 -> b1) ~(f2 : a2 -> b2)
      : (b1, b2) t =
    { evals =
        With_public_input.map t.evals
          ~f1:(Tuple_lib.Double.map ~f:f2)
          ~f2:(Tuple_lib.Double.map ~f:f2)
    ; ft_eval1 = f1 t.ft_eval1
    }

  let typ ~num_chunks feature_flags =
    let module Impl = Step_impl in
    let open Impl.Typ in
    let single = array ~length:num_chunks field in
    let dummy = Array.init num_chunks ~f:(fun _ -> Impl.Field.Constant.zero) in
    let evals =
      With_public_input.typ feature_flags (tuple2 single single)
        (tuple2 single single) ~dummy:(dummy, dummy)
    in
    of_hlistable [ evals; Impl.Field.typ ] ~var_to_hlist:In_circuit.to_hlist
      ~var_of_hlist:In_circuit.of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let wrap_typ ~num_chunks feature_flags =
    let module Impl = Wrap_impl in
    let open Impl.Typ in
    let single = array ~length:num_chunks field in
    let dummy = Array.init num_chunks ~f:(fun _ -> Impl.Field.Constant.zero) in
    let evals =
      With_public_input.wrap_typ feature_flags (tuple2 single single)
        (tuple2 single single) ~dummy:(dummy, dummy)
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
              ( 'g
              , 'fq )
              Mina_wire_types.Pickles_types.Plonk_types.Openings.Bulletproof.V1
              .t =
          { lr : ('g * 'g) Bounded_types.ArrayN16.Stable.V1.t
          ; z_1 : 'fq
          ; z_2 : 'fq
          ; delta : 'g
          ; challenge_polynomial_commitment : 'g
          }
        [@@deriving sexp, compare, yojson, hash, equal, hlist]
      end
    end]

    let typ fq g ~length =
      let open Step_impl.Typ in
      of_hlistable
        [ array ~length (g * g); fq; fq; g; g ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let wrap_typ fq g ~length =
      let open Wrap_impl.Typ in
      of_hlistable
        [ array ~length (g * g); fq; fq; g; g ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('g, 'fq, 'fqv) t =
            ( 'g
            , 'fq
            , 'fqv )
            Mina_wire_types.Pickles_types.Plonk_types.Openings.V2.t =
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
        type 'g_opt t =
          { unshifted : 'g_opt Bounded_types.ArrayN16.Stable.V1.t
          ; shifted : 'g_opt
          }
        [@@deriving sexp, compare, yojson, hlist, hash, equal]
      end
    end]

    let padded_array_typ0 = padded_array_typ

    let typ (type g g_var) (g : (g_var, g) Step_impl.Typ.t) ~length
        ~dummy_group_element :
        ( (Step_impl.Boolean.var * g_var) t
        , g Plonkish_prelude.Or_infinity.t t )
        Step_impl.Typ.t =
      let open Step_impl.Typ in
      let g_inf =
        transport
          (tuple2 Step_impl.Boolean.typ g)
          ~there:(function
            | Plonkish_prelude.Or_infinity.Infinity ->
                (false, dummy_group_element)
            | Finite x ->
                (true, x) )
          ~back:(fun (b, x) -> if b then Infinity else Finite x)
      in
      let arr =
        padded_array_typ0 ~length ~dummy:Plonkish_prelude.Or_infinity.Infinity
          g_inf
      in
      of_hlistable [ arr; g_inf ] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    let wrap_typ (type g g_var) (g : (g_var, g) Wrap_impl.Typ.t) ~length
        ~dummy_group_element :
        ( (Wrap_impl.Boolean.var * g_var) t
        , g Plonkish_prelude.Or_infinity.t t )
        Wrap_impl.Typ.t =
      let open Wrap_impl.Typ in
      let g_inf =
        transport
          (tuple2 Wrap_impl.Boolean.typ g)
          ~there:(function
            | Plonkish_prelude.Or_infinity.Infinity ->
                (false, dummy_group_element)
            | Finite x ->
                (true, x) )
          ~back:(fun (b, x) -> if b then Infinity else Finite x)
      in
      let arr =
        wrap_padded_array_typ ~length
          ~dummy:Plonkish_prelude.Or_infinity.Infinity g_inf
      in
      of_hlistable [ arr; g_inf ] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
  end

  module Without_degree_bound = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'g t = 'g Bounded_types.ArrayN16.Stable.V1.t
        [@@deriving sexp, compare, yojson, hash, equal]
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
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type 'g t =
              'g Mina_wire_types.Pickles_types.Plonk_types.Messages.Lookup.V1.t =
          { sorted : 'g Bounded_types.ArrayN16.Stable.V1.t
          ; aggreg : 'g
          ; runtime : 'g option
          }
        [@@deriving fields, sexp, compare, yojson, hash, equal, hlist]
      end
    end]

    type 'g t =
      { sorted : 'g Lookup_sorted_minus_1_vec.t
      ; sorted_5th_column : 'g option
      ; aggreg : 'g
      ; runtime : 'g option
      }
    [@@deriving fields, sexp, compare, yojson, hash, equal, hlist]

    module In_circuit = struct
      type ('g, 'bool) t =
        { sorted : 'g Lookup_sorted_minus_1_vec.t
        ; sorted_5th_column : ('g, 'bool) Plonkish_prelude.Opt.t
        ; aggreg : 'g
        ; runtime : ('g, 'bool) Plonkish_prelude.Opt.t
        }
      [@@deriving hlist]
    end

    let dummy z =
      { aggreg = z
      ; sorted =
          Plonkish_prelude.Vector.init Lookup_sorted_minus_1.n ~f:(fun _ -> z)
      ; sorted_5th_column = None
      ; runtime = None
      }

    let typ e ~lookups_per_row_4 ~runtime_tables ~dummy =
      Step_impl.Typ.of_hlistable
        [ Plonkish_prelude.Vector.typ e Lookup_sorted_minus_1.n
        ; Plonkish_prelude.Opt.typ lookups_per_row_4 e ~dummy
        ; e
        ; Plonkish_prelude.Opt.typ runtime_tables e ~dummy
        ]
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
        ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist

    let opt_typ ~(uses_lookup : Plonkish_prelude.Opt.Flag.t)
        ~(lookups_per_row_4 : Plonkish_prelude.Opt.Flag.t)
        ~(runtime_tables : Plonkish_prelude.Opt.Flag.t) ~dummy:z elt =
      Plonkish_prelude.Opt.typ uses_lookup ~dummy:(dummy z)
        (typ ~lookups_per_row_4 ~runtime_tables ~dummy:z elt)

    let wrap_typ e ~lookups_per_row_4 ~runtime_tables ~dummy =
      Wrap_impl.Typ.of_hlistable
        [ Plonkish_prelude.Vector.wrap_typ e Lookup_sorted_minus_1.n
        ; Plonkish_prelude.Opt.wrap_typ lookups_per_row_4 e ~dummy
        ; e
        ; Plonkish_prelude.Opt.wrap_typ runtime_tables e ~dummy
        ]
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
        ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist

    let wrap_opt_typ ~(uses_lookup : Plonkish_prelude.Opt.Flag.t)
        ~(lookups_per_row_4 : Plonkish_prelude.Opt.Flag.t)
        ~(runtime_tables : Plonkish_prelude.Opt.Flag.t) ~dummy:z elt =
      Plonkish_prelude.Opt.wrap_typ uses_lookup ~dummy:(dummy z)
        (wrap_typ ~lookups_per_row_4 ~runtime_tables ~dummy:z elt)
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type 'g t = 'g Mina_wire_types.Pickles_types.Plonk_types.Messages.V2.t =
        { w_comm : 'g Without_degree_bound.Stable.V1.t Columns_vec.Stable.V1.t
        ; z_comm : 'g Without_degree_bound.Stable.V1.t
        ; t_comm : 'g Without_degree_bound.Stable.V1.t
        ; lookup : 'g Without_degree_bound.Stable.V1.t Lookup.Stable.V1.t option
        }
      [@@deriving sexp, compare, yojson, fields, hash, equal, hlist]
    end
  end]

  type 'g t =
    { w_comm : 'g Without_degree_bound.t Columns_vec.t
    ; z_comm : 'g Without_degree_bound.t
    ; t_comm : 'g Without_degree_bound.t
    ; lookup : 'g Without_degree_bound.t Lookup.t option
    }
  [@@deriving sexp, compare, yojson, fields, hash, equal, hlist]

  module In_circuit = struct
    type ('g, 'bool) t =
      { w_comm : 'g Without_degree_bound.t Columns_vec.t
      ; z_comm : 'g Without_degree_bound.t
      ; t_comm : 'g Without_degree_bound.t
      ; lookup :
          ( ('g Without_degree_bound.t, 'bool) Lookup.In_circuit.t
          , 'bool )
          Plonkish_prelude.Opt.t
      }
    [@@deriving hlist, fields]
  end

  let typ (type n) g
      ({ runtime_tables; uses_lookups; lookups_per_row_4; _ } :
        Plonkish_prelude.Opt.Flag.t Features.Full.t ) ~dummy
      ~(commitment_lengths :
         (((int, n) Plonkish_prelude.Vector.t as 'v), int, int) Poly.t ) =
    let module Impl = Step_impl in
    let open Impl.Typ in
    let { Poly.w = w_lens; z; t } = commitment_lengths in
    let array ~length elt = padded_array_typ ~dummy ~length elt in
    let wo n =
      array ~length:(Plonkish_prelude.Vector.reduce_exn n ~f:Int.max) g
    in
    let _w n =
      With_degree_bound.typ g
        ~length:(Plonkish_prelude.Vector.reduce_exn n ~f:Int.max)
        ~dummy_group_element:dummy
    in
    let lookup =
      Lookup.opt_typ ~uses_lookup:uses_lookups ~lookups_per_row_4
        ~runtime_tables ~dummy:[| dummy |]
        (wo [ 1 ])
    in
    of_hlistable
      [ Plonkish_prelude.Vector.typ (wo w_lens) Columns.n
      ; wo [ z ]
      ; wo [ t ]
      ; lookup
      ]
      ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let wrap_typ (type n) g
      ({ runtime_tables; uses_lookups; lookups_per_row_4; _ } :
        Plonkish_prelude.Opt.Flag.t Features.Full.t ) ~dummy
      ~(commitment_lengths :
         (((int, n) Plonkish_prelude.Vector.t as 'v), int, int) Poly.t ) =
    let module Impl = Wrap_impl in
    let open Impl.Typ in
    let { Poly.w = w_lens; z; t } = commitment_lengths in
    let array ~length elt = wrap_padded_array_typ ~dummy ~length elt in
    let wo n =
      array ~length:(Plonkish_prelude.Vector.reduce_exn n ~f:Int.max) g
    in
    let _w n =
      With_degree_bound.wrap_typ g
        ~length:(Plonkish_prelude.Vector.reduce_exn n ~f:Int.max)
        ~dummy_group_element:dummy
    in
    let lookup =
      Lookup.wrap_opt_typ ~uses_lookup:uses_lookups ~lookups_per_row_4
        ~runtime_tables ~dummy:[| dummy |]
        (wo [ 1 ])
    in
    of_hlistable
      [ Plonkish_prelude.Vector.wrap_typ (wo w_lens) Columns.n
      ; wo [ z ]
      ; wo [ t ]
      ; lookup
      ]
      ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Proof = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type ('g, 'fq, 'fqv) t =
            ('g, 'fq, 'fqv) Mina_wire_types.Pickles_types.Plonk_types.Proof.V2.t =
        { messages : 'g Messages.Stable.V2.t
        ; openings : ('g, 'fq, 'fqv) Openings.Stable.V2.t
        }
      [@@deriving sexp, compare, yojson, hash, equal]
    end
  end]

  type ('g, 'fq, 'fqv) t =
    { messages : 'g Messages.t; openings : ('g, 'fq, 'fqv) Openings.t }
  [@@deriving sexp, compare, yojson, hash, equal]
end

module Shifts = struct
  open Core_kernel

  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'field t = 'field Bounded_types.ArrayN16.Stable.V1.t
      [@@deriving sexp, compare, yojson, equal]
    end
  end]
end
