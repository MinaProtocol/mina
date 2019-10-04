module type S = sig
  module Field : sig
    type t
  end

  module Fqe : sig
    type t

    val to_list : t -> Field.t list
  end

  module G1 : sig
    type t

    val to_affine_exn : t -> Field.t * Field.t

    val of_affine : Field.t * Field.t -> t
  end

  module G2 : sig
    type t

    val to_affine_exn : t -> Fqe.t * Fqe.t
  end

  val hash : Field.t array -> Field.t

  val group_map : Field.t -> Field.t * Field.t
end
