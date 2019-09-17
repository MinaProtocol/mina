module type S = sig
  module Field : sig
    type t

    val zero : t

    val ( * ) : t -> t -> t

    val ( + ) : t -> t -> t
  end

  val to_the_alpha : Field.t -> Field.t

  val alphath_root : Field.t -> Field.t
end
