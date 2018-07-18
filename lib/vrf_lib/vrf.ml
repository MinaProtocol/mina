module Make
         (Hash : sig
            type t

            val hash : bool list -> t
          end)
         (Scalar : sig
            type t

            val random: t
            val add: t -> t -> t

            val mul: t -> t -> t

            val from_hash: Hash.t -> t

            val fromBits: bool list -> t
            val toBits: t   -> bool list
          end)

           (Group : sig
            type t

            val add : t -> t -> t
            val inv : t -> t
            val scale : t -> Scalar.t -> t

            val generator : t

            val fromBits: bool list -> t
            val toBits: t   -> bool list
          end)
         (Hash_to_group : sig
            val hash : bool list -> Group.t
          end)
                : sig
  type proof
  type evaluation

  module Public_key : sig
    type t
  end
  module Private_key : sig
    type t

    val toScalar: t -> Scalar.t
  end
  module P_EQDL : sig
    type t
  end

  val eval : bool list -> Private_key.t -> evaluation
  (*l verify : Evaluation.t -> bool *)

end =
  struct

    module Public_key = struct
      type t = Group.t
    end

    module Private_key = struct
      type t = bool list

      let toScalar = Scalar.fromBits
    end

    module P_EQDL = struct
      type t = Hash.t * Scalar.t
    end

    type proof = Group.t * P_EQDL.t
    type evaluation = bool list * Hash.t * proof * Public_key.t

    let eval m prk =
      let k = Private_key.toScalar prk in
      let hgm = Hash_to_group.hash m in
      let u = (Group.scale hgm k) in
      let y = Hash.hash (List.append m (Group.toBits u)) in
      let g = Group.generator in
      let v = Group.scale g k in
      let r = Scalar.random in
      let gr = Group.scale g r in
      let hmr = Group.scale hgm r in
      let proof1 = Hash.hash (List.append (List.append m (Group.toBits v)) (List.append (Group.toBits gr) (Group.toBits hmr))) in
      let s = (Scalar.add r (Scalar.mul k (Scalar.from_hash proof1))) in
      let eqdl = (proof1, s) in
      let proof = (u, eqdl) in
      (m,y,proof,v)

  end
