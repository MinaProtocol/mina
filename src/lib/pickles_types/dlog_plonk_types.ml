open Core_kernel

module Pc_array = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = 'a array [@@deriving compare, sexp, yojson, eq]

      let hash_fold_t f s a = List.hash_fold_t f s (Array.to_list a)
    end
  end]

  let hash_fold_t f s a = List.hash_fold_t f s (Array.to_list a)
end

module Evals = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t =
        { l_eval: 'a
        ; r_eval: 'a
        ; o_eval: 'a
        ; z_eval: 'a
        ; t_eval: 'a
        ; f_eval: 'a
        ; sigma1_eval: 'a
        ; sigma2_eval: 'a }
      [@@deriving fields, sexp, compare, yojson, hash, eq]
    end
  end]

  let map (type a b)
      ({ l_eval
       ; r_eval
       ; o_eval
       ; z_eval
       ; t_eval
       ; f_eval
       ; sigma1_eval
       ; sigma2_eval } :
        a t) ~(fnc : a -> b) : b t =
    { l_eval= fnc l_eval
    ; r_eval= fnc r_eval
    ; o_eval= fnc o_eval
    ; z_eval= fnc z_eval
    ; t_eval= fnc t_eval
    ; f_eval= fnc f_eval
    ; sigma1_eval= fnc sigma1_eval
    ; sigma2_eval= fnc sigma2_eval }

  let map2 (type a b c) (t1 : a t) (t2 : b t) ~(f : a -> b -> c) : c t =
    { l_eval= f t1.l_eval t2.l_eval
    ; r_eval= f t1.r_eval t2.r_eval
    ; o_eval= f t1.o_eval t2.o_eval
    ; z_eval= f t1.z_eval t2.z_eval
    ; t_eval= f t1.t_eval t2.t_eval
    ; f_eval= f t1.f_eval t2.f_eval
    ; sigma1_eval= f t1.sigma1_eval t2.sigma1_eval
    ; sigma2_eval= f t1.sigma2_eval t2.sigma2_eval }

  let to_vectors
      { l_eval
      ; r_eval
      ; o_eval
      ; z_eval
      ; t_eval
      ; f_eval
      ; sigma1_eval
      ; sigma2_eval } =
    Vector.
      ( [ l_eval
        ; r_eval
        ; o_eval
        ; z_eval
        ; t_eval
        ; f_eval
        ; sigma1_eval
        ; sigma2_eval]
        , [])

  let of_vectors
      (( [ l_eval
         ; r_eval
         ; o_eval
         ; z_eval
         ; t_eval
         ; f_eval
         ; sigma1_eval
         ; sigma2_eval]
         , [] ) :
        ('a, _) Vector.t * ('a, _) Vector.t) : 'a t =
    { l_eval
    ; r_eval
    ; o_eval
    ; z_eval
    ; t_eval
    ; f_eval
    ; sigma1_eval
    ; sigma2_eval }

  let typ (lengths : int t) (g : ('a, 'b, 'f) Snarky_backendless.Typ.t)
      ~default : ('a array t, 'b array t, 'f) Snarky_backendless.Typ.t =
    let v ls =
      Vector.map ls ~f:(fun length ->
          let t = Snarky_backendless.Typ.array ~length g in
          { t with
            store=
              (fun arr ->
                t.store
                  (Array.append arr
                     (Array.create ~len:(length - Array.length arr) default))
                ) } )
    in
    let t =
      let l1, l2 = to_vectors lengths in
      Snarky_backendless.Typ.tuple2 (Vector.typ' (v l1)) (Vector.typ' (v l2))
    in
    Snarky_backendless.Typ.transport t ~there:to_vectors ~back:of_vectors
    |> Snarky_backendless.Typ.transport_var ~there:to_vectors ~back:of_vectors
end

module Openings = struct
  module Bulletproof = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('g, 'fq) t =
          { lr: ('g * 'g) Pc_array.Stable.V1.t
          ; z_1: 'fq
          ; z_2: 'fq
          ; delta: 'g
          ; sg: 'g }
        [@@deriving sexp, compare, yojson, hash, eq, hlist]
      end
    end]

    let typ fq g ~length =
      let open Snarky_backendless.Typ in
      of_hlistable
        [array ~length (g * g); fq; fq; g; g]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('g, 'fq, 'fqv) t =
        { proof: ('g, 'fq) Bulletproof.Stable.V1.t
        ; evals:
            'fqv Evals.Stable.V1.t
            * 'fqv Evals.Stable.V1.t }
      [@@deriving sexp, compare, yojson, hash, eq, hlist]
    end
  end]

  let typ (type g gv) (g : (gv, g, 'f) Snarky_backendless.Typ.t) fq
      ~bulletproof_rounds ~commitment_lengths ~dummy_group_element =
    let open Snarky_backendless.Typ in
    let tuple x = tuple2 x x in
    of_hlistable
      [ Bulletproof.typ fq g ~length:bulletproof_rounds
      ; tuple (Evals.typ ~default:dummy_group_element commitment_lengths g) ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Poly_comm = struct
  module With_degree_bound = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'g t = {unshifted: 'g Pc_array.Stable.V1.t; shifted: 'g}
        [@@deriving sexp, compare, yojson, hlist, hash, eq]
      end
    end]

    let typ ?(array = Snarky_backendless.Typ.array) g ~length =
      Snarky_backendless.Typ.of_hlistable [array ~length g; g]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Without_degree_bound = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'g t = 'g Pc_array.Stable.V1.t
        [@@deriving sexp, compare, yojson, hash, eq]
      end
    end]

    let typ g ~length = Snarky_backendless.Typ.array ~length g
  end
end

module Messages = struct
  open Poly_comm

  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'g t =
        { l_comm: 'g Without_degree_bound.Stable.V1.t
        ; r_comm: 'g Without_degree_bound.Stable.V1.t
        ; o_comm: 'g Without_degree_bound.Stable.V1.t
        ; z_comm: 'g Without_degree_bound.Stable.V1.t
        ; t_comm: 'g With_degree_bound.Stable.V1.t }
      [@@deriving sexp, compare, yojson, fields, hash, eq, hlist]
    end
  end]

  let typ (type n) g ~dummy
      ~(commitment_lengths : (int, n) Vector.t Evals.t) =
    let open Snarky_backendless.Typ in
    let {Evals.l_eval; r_eval; o_eval; z_eval; t_eval; _} =
      commitment_lengths
    in
    let array ~length elt =
      let typ = Snarky_backendless.Typ.array ~length elt in
      { typ with
        store=
          (fun a ->
            let n = Array.length a in
            if n > length then failwithf "Expected %d <= %d" n length () ;
            typ.store (Array.append a (Array.create ~len:(length - n) dummy))
            ) }
    in
    let wo n = array ~length:(Vector.reduce_exn n ~f:Int.max) g in
    let w n =
      With_degree_bound.typ ~array g ~length:(Vector.reduce_exn n ~f:Int.max)
    in
    of_hlistable
      [ wo l_eval
      ; wo r_eval
      ; wo o_eval
      ; wo z_eval
      ; w t_eval ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Proof = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('g, 'fq, 'fqv) t =
        { messages: 'g Messages.Stable.V1.t
        ; openings: ('g, 'fq, 'fqv) Openings.Stable.V1.t }
      [@@deriving sexp, compare, yojson, hash, eq]
    end
  end]
end
