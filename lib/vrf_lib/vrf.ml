module Make
         (Impl : Snarky.Snark_intf.S)
         (Hash : sig
            type t

            val hash : bool list -> t
            val equals: t -> t -> bool

            module Checked : sig
              open Impl

              type var

              val hash : Boolean.var list -> (var, _) Checked.t
              val equals : var -> var -> (Boolean.var, _) Checked.t
            end
          end)
         (Scalar : sig
            type t

            val random: t
            val add: t -> t -> t
            val mul: t -> t -> t

            val from_hash: Hash.t -> t

            val of_bits: bool list -> t
            val to_bits: t   -> bool list
          end)
         (Group : sig
            type t

            val add : t -> t -> t
            val inv : t -> t
            val scale : t -> Scalar.t -> t

            val generator : t

            val of_bits: bool list -> t
            val to_bits: t   -> bool list

            module Checked : sig
              open Impl

              type var

              val add : var -> var -> (var, _) Checked.t
              val inv : var -> (var, _) Checked.t
            end
          end)
         (Hash_to_group : sig
            val hash : bool list -> Group.t
          end)
                : sig
  type proof

  module Evaluation : sig
    type t
  end

  module Public_key : sig
    type t
  end
  module Private_key : sig
    type t

    val to_scalar: t -> Scalar.t
  end

  val eval : bool list -> Private_key.t -> Evaluation.t
  val verify : Evaluation.t -> bool
(*
  module Checked : sig
    open Impl

    type var

    val verify : var -> (bool,_) Checked.t
  end *)
end =
  struct

    module Public_key = struct
      type t = Group.t
    end

    module Private_key = struct
      type t = bool list

      let to_scalar = Scalar.of_bits
    end

    module P_EQDL = struct
      type t = Hash.t * Scalar.t

      let to_scalar eqdl =
        let (c,s) = eqdl in
        Scalar.from_hash c
    end

    type proof = Group.t * P_EQDL.t

    module Evaluation = struct
      type t = { m:bool list
               ; y:Hash.t
               ; proof:proof
               ; v:Public_key.t }
    end

    let eval m prk =
      let k = Private_key.to_scalar prk in
      let hgm = Hash_to_group.hash m in
      let u = (Group.scale hgm k) in
      let y = Hash.hash (m @ (Group.to_bits u)) in
      let g = Group.generator in
      let v = Group.scale g k in
      let r = Scalar.random in
      let gr = Group.scale g r in
      let hmr = Group.scale hgm r in
      let proof1 = Hash.hash (m @ (Group.to_bits v) @ (Group.to_bits gr) @ (Group.to_bits hmr)) in
      let s = (Scalar.add r (Scalar.mul k (Scalar.from_hash proof1))) in
      let eqdl = (proof1, s) in
      let proof = (u, eqdl) in
      {Evaluation.m; y; proof; v}

    let verify evaluated =
      let {Evaluation.m;y;proof;v} = evaluated in
      let (u, eqdl) = proof in
      let (proof1, s) = eqdl in
      let y1 = Hash.hash (m @ (Group.to_bits u)) in
      let g = Group.generator in
      let gs = Group.scale g s in
      let c = P_EQDL.to_scalar eqdl in
      let vnegc = Group.scale (Group.inv v) c in
      let gsvc = Group.add gs vnegc in
      let hms = Group.scale (Hash_to_group.hash m) s in
      let unegc = Group.scale (Group.inv u) c in
      let hmsuc = Group.add hms unegc in
      let c1 = Hash.hash (m @ (Group.to_bits v) @ (Group.to_bits gsvc) @ (Group.to_bits hmsuc)) in
      let b1 = Hash.equals y y1 in
      let b2 = Hash.equals proof1 c1 in
      b1 && b2

    end
