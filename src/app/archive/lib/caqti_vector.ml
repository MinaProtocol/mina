(* caqti_vector.ml -- Caqti encoding for Pickles_types.Vector

   Lives here rather than in Mina_caqti so that Mina_caqti needs no part of
   the protocol stack: this is the only consumer, and Pickles_types brings 29
   libraries with it. *)

type (_, _, _, _) t =
  | [] : ('elem, unit, unit, Pickles_types.Nat.z) t
  | ( :: ) :
      'elem Caqti_type.t * ('elem, 'fun_t, 'tup_t, 'n) t
      -> ('elem, 'elem -> 'fun_t, 'elem * 'tup_t, 'n Pickles_types.Nat.s) t

let rec vec_to_hlist :
          'elem 'hlist 'tup 'n.
             ('elem, 'hlist, 'tup, 'n) t
          -> ('elem, 'n) Pickles_types.Vector.t
          -> (unit, 'hlist) H_list.t =
  fun (type elem hlist tup n) (spec : (elem, hlist, tup, n) t)
      (v : (elem, n) Pickles_types.Vector.t) ->
   match (spec, v) with
   | [], [] ->
       ([] : (unit, hlist) H_list.t)
   | _ :: spec, x :: v ->
       x :: vec_to_hlist spec v

let rec hlist_to_vec :
          'elem 'hlist 'tup 'n.
             ('elem, 'hlist, 'tup, 'n) t
          -> (unit, 'hlist) H_list.t
          -> ('elem, 'n) Pickles_types.Vector.t =
  fun (type elem hlist tup n) (spec : (elem, hlist, tup, n) t)
      (l : (unit, hlist) H_list.t) ->
   match (spec, l) with
   | _ :: spec, x :: l ->
       (x :: hlist_to_vec spec l : (elem, n) Pickles_types.Vector.t)
   | [], [] ->
       []

module type Intf = sig
  (** defines a function type, like ['elem -> 'elem -> ... -> 'elem -> unit] *)
  type 'elem fun_t

  (** defines a tuple type, like ['elem * 'elem * ... * 'elem * unit] *)
  type 'elem tup_t

  type n

  val spec : 'elem Caqti_type.t -> ('elem, 'elem fun_t, 'elem tup_t, n) t

  val type_spec :
    'elem Caqti_type.t -> ('elem fun_t, 'elem tup_t) Mina_caqti.Type_spec.t
end

let rec spec_of_nat :
    type n. n Plonkish_prelude.Nat.nat -> (module Intf with type n = n) =
  function
  | Z ->
      let module N = struct
        type 'elem fun_t = unit

        type 'elem tup_t = unit

        type n = Pickles_types.Nat.z

        let spec _ = []

        let type_spec _ = Mina_caqti.Type_spec.[]
      end in
      (module N : Intf with type n = n)
  | S p ->
      let (module Prev) = spec_of_nat p in
      let module N = struct
        type 'elem fun_t = 'elem -> 'elem Prev.fun_t

        type 'elem tup_t = 'elem * 'elem Prev.tup_t

        type n = Prev.n Pickles_types.Nat.s

        let spec :
            type elem. elem Caqti_type.t -> (elem, elem fun_t, elem tup_t, n) t
            =
         fun t -> t :: Prev.spec t

        let type_spec :
               'elem Caqti_type.t
            -> ('elem fun_t, 'elem tup_t) Mina_caqti.Type_spec.t =
         fun t -> t :: Prev.type_spec t
      end in
      (module N : Intf with type n = n)

let typ :
    type elem n.
       elem Caqti_type.t * n Plonkish_prelude.Nat.nat
    -> (elem, n) Pickles_types.Vector.vec Caqti_type.t =
 fun (elem, n) ->
  let (module M) = spec_of_nat n in
  Mina_caqti.Type_spec.custom_type
    ~to_hlist:(vec_to_hlist (M.spec elem))
    ~of_hlist:(hlist_to_vec (M.spec elem))
    (M.type_spec elem)
