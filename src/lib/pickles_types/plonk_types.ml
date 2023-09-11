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
module Lookup_sorted_minus_1 = Nat.N4
module Lookup_sorted_minus_1_vec = Vector.Vector_4
module Lookup_sorted = Nat.N5
module Lookup_sorted_vec = Vector.Vector_5

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
      { range_check0 = Opt.Flag.No
      ; range_check1 = Opt.Flag.No
      ; foreign_field_add = Opt.Flag.No
      ; foreign_field_mul = Opt.Flag.No
      ; xor = Opt.Flag.No
      ; rot = Opt.Flag.No
      ; lookup = Opt.Flag.No
      ; runtime_tables = Opt.Flag.No
      ; uses_lookups = Opt.Flag.No
      ; table_width_at_least_1 = Opt.Flag.No
      ; table_width_at_least_2 = Opt.Flag.No
      ; table_width_3 = Opt.Flag.No
      ; lookups_per_row_3 = Opt.Flag.No
      ; lookups_per_row_4 = Opt.Flag.No
      ; lookup_pattern_xor = Opt.Flag.No
      ; lookup_pattern_range_check = Opt.Flag.No
      }

    let maybe =
      { range_check0 = Opt.Flag.Maybe
      ; range_check1 = Opt.Flag.Maybe
      ; foreign_field_add = Opt.Flag.Maybe
      ; foreign_field_mul = Opt.Flag.Maybe
      ; xor = Opt.Flag.Maybe
      ; rot = Opt.Flag.Maybe
      ; lookup = Opt.Flag.Maybe
      ; runtime_tables = Opt.Flag.Maybe
      ; uses_lookups = Opt.Flag.Maybe
      ; table_width_at_least_1 = Opt.Flag.Maybe
      ; table_width_at_least_2 = Opt.Flag.Maybe
      ; table_width_3 = Opt.Flag.Maybe
      ; lookups_per_row_3 = Opt.Flag.Maybe
      ; lookups_per_row_4 = Opt.Flag.Maybe
      ; lookup_pattern_xor = Opt.Flag.Maybe
      ; lookup_pattern_range_check = Opt.Flag.Maybe
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

  let to_full ~or_:( ||| )
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
      table_width_at_least_2 ||| lookup_pattern_range_check
      ||| foreign_field_mul
    in
    let lookups_per_row_4 =
      (* Xor, RangeCheckGate, ForeignFieldMul, have max_lookups_per_row = 4 *)
      lookup_pattern_xor ||| lookup_pattern_range_check ||| foreign_field_mul
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

  let maybe =
    { range_check0 = Opt.Flag.Maybe
    ; range_check1 = Opt.Flag.Maybe
    ; foreign_field_add = Opt.Flag.Maybe
    ; foreign_field_mul = Opt.Flag.Maybe
    ; xor = Opt.Flag.Maybe
    ; rot = Opt.Flag.Maybe
    ; lookup = Opt.Flag.Maybe
    ; runtime_tables = Opt.Flag.Maybe
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
      let always_present =
        List.map ~f:Opt.just
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

      List.map ~f:Opt.just always_present
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
      ~dummy e
      ({ uses_lookups; lookups_per_row_3; lookups_per_row_4; _ } as
       feature_flags :
        _ Features.Full.t ) :
      ((a_var, Impl.Boolean.var) In_circuit.t, a t, f) Snarky_backendless.Typ.t
      =
    let open Impl in
    let opt flag = Opt.typ Impl.Boolean.typ flag e ~dummy in
    let lookup_sorted =
      let lookups_per_row_3 = opt lookups_per_row_3 in
      let lookups_per_row_4 = opt lookups_per_row_4 in
      Vector.typ'
        [ lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_3
        ; lookups_per_row_4
        ]
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
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type 'g t = { sorted : 'g array; aggreg : 'g; runtime : 'g option }
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
        ; sorted_5th_column : ('g, 'bool) Opt.t
        ; aggreg : 'g
        ; runtime : ('g, 'bool) Opt.t
        }
      [@@deriving hlist]
    end

    let dummy z =
      { aggreg = z
      ; sorted = Vector.init Lookup_sorted_minus_1.n ~f:(fun _ -> z)
      ; sorted_5th_column = None
      ; runtime = None
      }

    let typ bool_typ e ~lookups_per_row_4 ~runtime_tables ~dummy =
      Snarky_backendless.Typ.of_hlistable
        [ Vector.typ e Lookup_sorted_minus_1.n
        ; Opt.typ bool_typ lookups_per_row_4 e ~dummy
        ; e
        ; Opt.typ bool_typ runtime_tables e ~dummy
        ]
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
        ~var_to_hlist:In_circuit.to_hlist ~var_of_hlist:In_circuit.of_hlist

    let opt_typ bool_typ ~(uses_lookup : Opt.Flag.t)
        ~(lookups_per_row_4 : Opt.Flag.t) ~(runtime_tables : Opt.Flag.t)
        ~dummy:z elt =
      Opt.typ bool_typ uses_lookup ~dummy:(dummy z)
        (typ bool_typ ~lookups_per_row_4 ~runtime_tables ~dummy:z elt)
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

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
          (('g Without_degree_bound.t, 'bool) Lookup.In_circuit.t, 'bool) Opt.t
      }
    [@@deriving hlist, fields]
  end

  let typ (type n f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) g
      ({ runtime_tables; uses_lookups; lookups_per_row_4; _ } :
        Opt.Flag.t Features.Full.t ) ~dummy
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
      Lookup.opt_typ Impl.Boolean.typ ~uses_lookup:uses_lookups
        ~lookups_per_row_4 ~runtime_tables ~dummy:[| dummy |]
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
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type ('g, 'fq, 'fqv) t =
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
      type 'field t = 'field array [@@deriving sexp, compare, yojson, equal]
    end
  end]
end
