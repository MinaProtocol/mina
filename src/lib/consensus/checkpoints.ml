open Core
open Fold_lib
open Module_version
open Snark_params.Tick

module Hash = Coda_base.Data_hash.Make_full_size ()

let merge (s : Coda_base.State_hash.t) (h : Hash.t) =
  Snark_params.Tick.Pedersen.digest_fold Coda_base.Hash_prefix.checkpoint_list
    Fold.(Coda_base.State_hash.fold s +> Hash.fold h)
  |> Hash.of_hash

let max_length = 12

module Repr = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { (* TODO: Make a nice way to force this to have bounded (or fixed) size for
                bin_io reasons *)
            (* Front is oldest. Back is newest *)
            prefix: Coda_base.State_hash.Stable.V1.t Core.Fdeque.Stable.V1.t
          ; tail: Hash.Stable.V1.t }
        [@@deriving sexp, bin_io, compare, version]

        let digest ({prefix; tail} : t) =
          let rec go acc p =
            match Fdeque.dequeue_front p with
            | None ->
                acc
            | Some (h, p) ->
                go (merge h acc) p
          in
          go tail prefix
      end

      include T

      module Yojson = struct
        type t =
          { prefix: Coda_base.State_hash.Stable.V1.t list
          ; tail: Hash.Stable.V1.t }
        [@@deriving to_yojson]
      end

      let to_yojson ({prefix; tail} : t) =
        Yojson.to_yojson {prefix= Fdeque.to_list prefix; tail}
    end

    module Latest = V1
  end

  type t = Stable.Latest.t =
    {prefix: Coda_base.State_hash.t Fdeque.t; tail: Hash.t}
  [@@deriving sexp, hash, compare]

  let to_yojson = Stable.V1.to_yojson

  let equal t1 t2 = compare t1 t2 = 0

  let digest = Stable.V1.digest
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t = (Repr.Stable.V1.t, Hash.Stable.V1.t) With_hash.Stable.V1.t
      [@@deriving sexp, version, to_yojson]

      let compare (t1 : t) (t2 : t) = Hash.compare t1.hash t2.hash

      let equal (t1 : t) (t2 : t) = Hash.equal t1.hash t2.hash

      let hash (t : t) = Hash.hash t.hash

      let hash_fold_t s (t : t) = Hash.hash_fold_t s t.hash

      let to_repr (t : t) = t.data

      let of_repr r =
        {With_hash.Stable.V1.data= r; hash= Repr.Stable.V1.digest r}

      include Binable.Of_binable
                (Repr.Stable.V1)
                (struct
                  type nonrec t = t

                  let to_binable = to_repr

                  let of_binable = of_repr
                end)
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "checkpoints_proof_of_stake"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

type t = (Repr.t, Hash.t) With_hash.t [@@deriving sexp, to_yojson]

let compare, equal, hash, hash_fold_t =
  Stable.Latest.(compare, equal, hash, hash_fold_t)

let empty : t =
  let dummy = Hash.of_hash Snark_params.Tick.Field.zero in
  {hash= dummy; data= {prefix= Fdeque.empty; tail= dummy}}

let cons sh (t : t) : t =
  (* This kind of defeats the purpose of having a queue, but oh well. *)
  let n = Fdeque.length t.data.prefix in
  let hash = merge sh t.hash in
  let {Repr.prefix; tail} = t.data in
  if n < max_length then
    {hash; data= {prefix= Fdeque.enqueue_back prefix sh; tail}}
  else
    let sh0, prefix = Fdeque.dequeue_front_exn prefix in
    {hash; data= {prefix= Fdeque.enqueue_back prefix sh; tail= merge sh0 tail}}

let overlap (t1 : t) (t2 : t) =
  let exists t ~f =
    (* From newest to oldest *)
    Fdeque.Back_to_front.fold_until t ~init:0
      ~f:(fun n x ->
        if n >= max_length then Stop false
        else if f x then Stop true
        else Continue (n + 1) )
      ~finish:(fun _ -> false)
  in
  exists t1.data.prefix ~f:(fun h1 ->
      exists t2.data.prefix ~f:(fun h2 -> Coda_base.State_hash.equal h1 h2) )

let fold (t : t) = Hash.fold t.hash

let length_in_triples = Hash.length_in_triples

type var = Hash.var

let typ =
  Typ.transport Hash.typ
    ~there:(fun (t : t) -> t.hash)
    ~back:(fun hash -> {hash; data= {prefix= Fdeque.empty; tail= hash}})

module Checked = struct
  type t = var

  let if_ = Hash.if_

  let cons sh t =
    let open Snark_params.Tick in
    let open Checked in
    let%bind sh = Coda_base.State_hash.var_to_triples sh
    and t = Hash.var_to_triples t in
    Pedersen.Checked.digest_triples ~init:Coda_base.Hash_prefix.checkpoint_list
      (sh @ t)
    >>| Hash.var_of_hash_packed
end
