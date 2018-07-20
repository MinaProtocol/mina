module Make
    (Impl : Snarky.Snark_intf.S) (Hash : sig
        type t

        val hash : bool list -> t

        val equals : t -> t -> bool

        module Checked : sig
          open Impl

          type var

          val hash : Boolean.var list -> (var, _) Checked.t

          val equals : var -> var -> (Boolean.var, _) Checked.t
        end
    end) (Scalar : sig
      type t

      val random : t

      val add : t -> t -> t

      val mul : t -> t -> t

      val from_hash : Hash.t -> t

      val of_bits : bool list -> t

      val to_bits : t -> bool list

      module Checked : sig
        open Impl

        type var

        val from_hash : Hash.Checked.var -> (var, _) Checked.t
      end
    end) (Group : sig
      type t

      val add : t -> t -> t

      val inv : t -> t

      val scale : t -> Scalar.t -> t

      val generator : t

      val of_bits : bool list -> t

      val to_bits : t -> bool list

      module Checked : sig
        open Impl

        type var

        val add : var -> var -> (var, _) Checked.t

        val inv : var -> (var, _) Checked.t

        val scale_known : t -> Scalar.Checked.var -> (var, _) Checked.t

        val scale : var -> Scalar.Checked.var -> (var, _) Checked.t

        val generator : var

        val of_bits : Boolean.var list -> (var, _) Checked.t

        val to_bits : var -> (Boolean.var list, _) Checked.t
      end
    end) (Hash_to_group : sig
      val hash : bool list -> Group.t

      module Checked : sig
        open Impl

        type var

        val hash : Boolean.var list -> (Group.Checked.var, _) Checked.t
      end
    end) : sig
  module Evaluation : sig
    type t
  end

  module Public_key : sig
    type t
  end

  module Private_key : sig
    type t

    val to_scalar : t -> Scalar.t
  end

  val eval : bool list -> Private_key.t -> Evaluation.t

  val verify : Evaluation.t -> bool

  module Checked : sig
    open Impl

    type var

    val verify : var -> (Boolean.var, _) Checked.t
  end
end = struct
  module Public_key = struct
    type t = Group.t

    module Checked = struct
      type var = Group.Checked.var
    end
  end

  module Private_key = struct
    type t = bool list

    let to_scalar = Scalar.of_bits
  end

  module EQDL = struct
    type t = Hash.t * Scalar.t

    let to_scalar eqdl =
      let c, s = eqdl in
      Scalar.from_hash c

    module Checked = struct
      type var = Hash.Checked.var * Scalar.Checked.var

      let to_scalar eqdl =
        let c, s = eqdl in
        Scalar.Checked.from_hash c
    end
  end

  module VRFProof = struct
    type t = Group.t * EQDL.t

    module Checked = struct
      type var = Group.Checked.var * EQDL.Checked.var
    end
  end

  module Evaluation = struct
    type t = {m: bool list; y: Hash.t; proof: VRFProof.t; v: Public_key.t}

    module Checked = struct
      open Impl

      type var =
        { m: Boolean.var list
        ; y: Hash.Checked.var
        ; proof: VRFProof.Checked.var
        ; v: Public_key.Checked.var }
    end
  end

  let eval m prk =
    let k = Private_key.to_scalar prk in
    let hgm = Hash_to_group.hash m in
    let u = Group.scale hgm k in
    let y = Hash.hash (m @ Group.to_bits u) in
    let g = Group.generator in
    let v = Group.scale g k in
    let r = Scalar.random in
    let gr = Group.scale g r in
    let hmr = Group.scale hgm r in
    let proof1 =
      Hash.hash (m @ Group.to_bits v @ Group.to_bits gr @ Group.to_bits hmr)
    in
    let s = Scalar.add r (Scalar.mul k (Scalar.from_hash proof1)) in
    let eqdl = (proof1, s) in
    let proof = (u, eqdl) in
    {Evaluation.m; y; proof; v}

  let verify evaluated =
    let {Evaluation.m; y; proof; v} = evaluated in
    let u, eqdl = proof in
    let proof1, s = eqdl in
    let y1 = Hash.hash (m @ Group.to_bits u) in
    let g = Group.generator in
    let gs = Group.scale g s in
    let c = EQDL.to_scalar eqdl in
    let vnegc = Group.scale (Group.inv v) c in
    let gsvc = Group.add gs vnegc in
    let hms = Group.scale (Hash_to_group.hash m) s in
    let unegc = Group.scale (Group.inv u) c in
    let hmsuc = Group.add hms unegc in
    let c1 =
      Hash.hash (m @ Group.to_bits v @ Group.to_bits gsvc @ Group.to_bits hmsuc)
    in
    let b1 = Hash.equals y y1 in
    let b2 = Hash.equals proof1 c1 in
    b1 && b2

  module Checked = struct
    type var = Evaluation.Checked.var

    let verify evaluated =
      let open Impl.Checked.Let_syntax in
      let {Evaluation.Checked.m; y; proof; v} = evaluated in
      let u, eqdl = proof in
      let proof1, s = eqdl in
      let%bind uc = Group.Checked.to_bits u in
      let%bind y1 = Hash.Checked.hash (m @ uc) in
      let%bind gs = Group.Checked.scale_known Group.generator s in
      let%bind c = EQDL.Checked.to_scalar eqdl in
      let%bind vi = Group.Checked.inv v in
      let%bind vnegc = Group.Checked.scale vi c in
      let%bind gsvc = Group.Checked.add gs vnegc in
      let%bind hm = Hash_to_group.Checked.hash m in
      let%bind hms = Group.Checked.scale hm s in
      let%bind ui = Group.Checked.inv u in
      let%bind unegc = Group.Checked.scale ui c in
      let%bind hmsuc = Group.Checked.add hms unegc in
      let%bind vb = Group.Checked.to_bits v in
      let%bind gsvcb = Group.Checked.to_bits gsvc in
      let%bind hmsucb = Group.Checked.to_bits hmsuc in
      let%bind c1 = Hash.Checked.hash (m @ vb @ gsvcb @ hmsucb) in
      let%bind b1 = Hash.Checked.equals y y1 in
      let%bind b2 = Hash.Checked.equals proof1 c1 in
      Impl.Boolean.( && ) b1 b2
  end
end
