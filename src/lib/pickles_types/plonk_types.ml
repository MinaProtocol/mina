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

module Opt = struct
  type ('a, 'bool) t = Some of 'a | None | Maybe of 'bool * 'a

  let of_option (t : 'a option) : ('a, 'bool) t =
    match t with None -> None | Some x -> Some x

  module Flag = struct
    type t = Yes | No | Maybe [@@deriving sexp, compare, yojson, hash, equal]
  end

  let map t ~f =
    match t with
    | None ->
        None
    | Some x ->
        Some (f x)
    | Maybe (b, x) ->
        Maybe (b, f x)

  let map2_exn (type a b c bool) (t1 : (a, bool) t) (t2 : (b, bool) t)
      ~(f : a -> b -> c) =
    match (t1, t2) with
    | None, None ->
        None
    | Some x1, Some x2 ->
        Some (f x1 x2)
    | Some x1, Maybe (b2, x2) ->
        Maybe (b2, f x1 x2)
    | Maybe (b1, x1), Some x2 ->
        Maybe (b1, f x1 x2)
    | Maybe (_b1, _x1), Maybe (_b2, _x2) ->
        failwith "Opt.map2_exn: (Maybe, Maybe)"
    | Some _, None ->
        failwith "Opt.map2_exn: (Some, None)"
    | None, Some _ ->
        failwith "Opt.map2_exn: (None, Some)"
    | Maybe _, None ->
        failwith "Opt.map2_exn: (Maybe, None)"
    | None, Maybe _ ->
        failwith "Opt.map2_exn: (None, Maybe)"

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

  let maybe_typ (type a a_var f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      ~(dummy : a) (a_typ : (a_var, a, f) Typ.t) :
      ((a_var, Impl.Boolean.var) t, a option, f) Typ.t =
    Typ.transport
      (Typ.tuple2 Impl.Boolean.typ a_typ)
      ~there:(fun (t : a option) ->
        match t with None -> (false, dummy) | Some x -> (true, x) )
      ~back:(fun (b, x) -> if b then Some x else None)
    |> Typ.transport_var
         ~there:(fun (t : (a_var, Impl.Boolean.var) t) ->
           match t with
           | Maybe (b, x) ->
               (b, x)
           | None | Some _ ->
               failwith "Opt.some_typ: expected Some" )
         ~back:(fun (b, x) -> Maybe (b, x))

  let typ (type a a_var f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      (flag : Flag.t) (a_typ : (a_var, a, f) Typ.t) ~(dummy : a) =
    match flag with
    | Yes ->
        some_typ a_typ
    | No ->
        none_typ ()
    | Maybe ->
        maybe_typ (module Impl) ~dummy a_typ

  module Early_stop_sequence = struct
    (* A sequence that should be considered to have stopped at
       the first No flag *)
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

module Evals = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'a t =
        { w : 'a Columns_vec.Stable.V1.t
        ; z : 'a
        ; s : 'a Permuts_minus_1_vec.Stable.V1.t
        ; generic_selector : 'a
        ; poseidon_selector : 'a
        }
      [@@deriving fields, sexp, compare, yojson, hash, equal]
    end
  end]

  let map (type a b) ({ w; z; s; generic_selector; poseidon_selector } : a t)
      ~(f : a -> b) : b t =
    { w = Vector.map w ~f
    ; z = f z
    ; s = Vector.map s ~f
    ; generic_selector = f generic_selector
    ; poseidon_selector = f poseidon_selector
    }

  let map2 (type a b c) (t1 : a t) (t2 : b t) ~(f : a -> b -> c) : c t =
    { w = Vector.map2 t1.w t2.w ~f
    ; z = f t1.z t2.z
    ; s = Vector.map2 t1.s t2.s ~f
    ; generic_selector = f t1.generic_selector t2.generic_selector
    ; poseidon_selector = f t1.poseidon_selector t2.poseidon_selector
    }

  let w_s_len, w_s_add_proof = Columns.add Permuts_minus_1.n

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
     - w (witness columns)
     - s (sigma columns)
  *)
  let to_vectors { w; z; s; generic_selector; poseidon_selector } =
    let w_s = Vector.append w s w_s_add_proof in
    (Vector.(z :: generic_selector :: poseidon_selector :: w_s), Vector.[])

  let of_vectors
      ( (z :: generic_selector :: poseidon_selector :: w_s : ('a, _) Vector.t)
      , Vector.[] ) : 'a t =
    let w, s = Vector.split w_s w_s_add_proof in
    { w; z; s; generic_selector; poseidon_selector }

  let typ (lengths : int t) (g : ('a, 'b, 'f) Snarky_backendless.Typ.t) ~default
      : ('a array t, 'b array t, 'f) Snarky_backendless.Typ.t =
    let v ls =
      Vector.map ls ~f:(fun length ->
          Snarky_backendless.Typ.array ~length g
          |> Snarky_backendless.Typ.transport
               ~there:(fun arr ->
                 Array.append arr
                   (Array.create ~len:(length - Array.length arr) default) )
               ~back:Fn.id )
    in
    let t =
      let l1, l2 = to_vectors lengths in
      Snarky_backendless.Typ.tuple2 (Vector.typ' (v l1)) (Vector.typ' (v l2))
    in
    Snarky_backendless.Typ.transport t ~there:to_vectors ~back:of_vectors
    |> Snarky_backendless.Typ.transport_var ~there:to_vectors ~back:of_vectors
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

    let map (type a1 a2 b1 b2) (t : (a1, a2) t) ~(f1 : a1 -> b1) ~(f2 : a2 -> b2)
        : (b1, b2) t =
      { public_input = f1 t.public_input; evals = Evals.map ~f:f2 t.evals }

    let typ lengths (elt : ('a, 'b, 'f) Snarky_backendless.Typ.t) ~default =
      let open Snarky_backendless.Typ in
      let evals = Evals.typ lengths elt ~default in
      of_hlistable [ elt; evals ] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('f, 'f_multi) t =
        { evals :
            ('f, 'f_multi) With_public_input.Stable.V1.t
            * ('f, 'f_multi) With_public_input.Stable.V1.t
        ; ft_eval1 : 'f
        }
      [@@deriving sexp, compare, yojson, hash, equal, hlist]
    end
  end]

  let map (type a1 a2 b1 b2) (t : (a1, a2) t) ~(f1 : a1 -> b1) ~(f2 : a2 -> b2)
      : (b1, b2) t =
    { evals = Tuple_lib.Double.map t.evals ~f:(With_public_input.map ~f1 ~f2)
    ; ft_eval1 = f1 t.ft_eval1
    }

  let typ lengths (elt : ('a, 'b, 'f) Snarky_backendless.Typ.t) ~default =
    let open Snarky_backendless.Typ in
    let evals = With_public_input.typ lengths elt ~default in
    of_hlistable
      [ tuple2 evals evals; elt ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Openings = struct
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
        ; evals : 'fqv Evals.Stable.V2.t * 'fqv Evals.Stable.V2.t
        ; ft_eval1 : 'fq
        }
      [@@deriving sexp, compare, yojson, hash, equal, hlist]
    end
  end]

  let typ (type g gv) (g : (gv, g, 'f) Snarky_backendless.Typ.t) fq
      ~bulletproof_rounds ~commitment_lengths ~dummy_group_element =
    let open Snarky_backendless.Typ in
    let double x = tuple2 x x in
    of_hlistable
      [ Bulletproof.typ fq g ~length:bulletproof_rounds
      ; double (Evals.typ ~default:dummy_group_element commitment_lengths g)
      ; fq
      ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
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

    let map { unshifted; shifted } ~f =
      { unshifted = Array.map ~f unshifted; shifted = f shifted }

    let padded_array_typ0 = padded_array_typ

    let padded_array_typ elt ~length ~dummy ~bool =
      let open Snarky_backendless.Typ in
      array ~length (tuple2 bool elt)
      |> transport
           ~there:(fun a ->
             let a = Array.map a ~f:(fun x -> (true, x)) in
             let n = Array.length a in
             if n > length then failwithf "Expected %d <= %d" n length () ;
             Array.append a (Array.create ~len:(length - n) (false, dummy)) )
           ~back:(fun a ->
             Array.filter_map a ~f:(fun (b, g) -> if b then Some g else None) )

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

    let typ g ~length = Snarky_backendless.Typ.array ~length g
  end
end

module Messages = struct
  open Poly_comm

  module Poly = struct
    type ('w, 'z, 't) t = { w : 'w; z : 'z; t : 't }
    [@@deriving sexp, compare, yojson, fields, hash, equal, hlist]
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'g t =
        { w_comm : 'g Without_degree_bound.Stable.V1.t Columns_vec.Stable.V1.t
        ; z_comm : 'g Without_degree_bound.Stable.V1.t
        ; t_comm : 'g Without_degree_bound.Stable.V1.t
        }
      [@@deriving sexp, compare, yojson, fields, hash, equal, hlist]
    end
  end]

  let typ (type n) g ~dummy
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
    of_hlistable
      [ Vector.typ (wo w_lens) Columns.n; wo [ z ]; wo [ t ] ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
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

  let map = Array.map
end
