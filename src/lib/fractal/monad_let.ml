(** The usual Janestreet [Monad] interfaces, with [Let_syntax] included in the
    monad module. *)
open Core_kernel

open Monad

module type Let_syntax = sig
  type 'a t

  val return : 'a -> 'a t

  val bind : 'a t -> f:('a -> 'b t) -> 'b t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val both : 'a t -> 'b t -> ('a * 'b) t

  module Open_on_rhs : sig end
end

module type Base_syntax = sig
  type 'a t

  val return : 'a -> 'a t

  include Infix with type 'a t := 'a t
end

module type Syntax = sig
  include Base_syntax

  include Let_syntax with type 'a t := 'a t
end

module type S = sig
  type 'a t

  include S_without_syntax with type 'a t := 'a t

  module Let_syntax : sig
    include Base_syntax with type 'a t := 'a t

    include Let_syntax with type 'a t := 'a t

    module Let_syntax : Let_syntax with type 'a t := 'a t
  end
end

module Make (X : Monad.Basic) : S with type 'a t := 'a X.t = struct
  include X
  module M = Monad.Make (X)
  module Let = M.Let_syntax.Let_syntax

  include (M : S_without_syntax with type 'a t := 'a t)

  module Let_syntax = struct
    include (M.Let_syntax : Base_syntax with type 'a t := 'a t)

    include (Let : Let_syntax with type 'a t := 'a t)

    module Let_syntax = Let
  end
end

module type Let_syntax2 = sig
  type ('a, 'e) t

  val return : 'a -> ('a, 'e) t

  val bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t

  val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t

  val both : ('a, 'e) t -> ('b, 'e) t -> ('a * 'b, 'e) t

  module Open_on_rhs : sig end
end

module type Base_syntax2 = sig
  type ('a, 'e) t

  val return : 'a -> ('a, 'e) t

  include Infix2 with type ('a, 'e) t := ('a, 'e) t
end

module type Syntax2 = sig
  include Base_syntax2

  include Let_syntax2 with type ('a, 'e) t := ('a, 'e) t
end

module type S_without_syntax2 = sig
  type ('a, 'e) t

  include Infix2 with type ('a, 'e) t := ('a, 'e) t

  module Monad_infix : Infix2 with type ('a, 'e) t := ('a, 'e) t

  val bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t

  val return : 'a -> ('a, _) t

  val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t

  val join : (('a, 'e) t, 'e) t -> ('a, 'e) t

  val ignore_m : (_, 'e) t -> (unit, 'e) t

  val all : ('a, 'e) t list -> ('a list, 'e) t

  val all_unit : (unit, 'e) t list -> (unit, 'e) t

  val all_ignore : (unit, 'e) t list -> (unit, 'e) t
    [@@deprecated "[since 2018-02] Use [all_unit]"]
end

module type S2 = sig
  type ('a, 'e) t

  include S_without_syntax2 with type ('a, 'e) t := ('a, 'e) t

  module Let_syntax : sig
    include Base_syntax2 with type ('a, 'e) t := ('a, 'e) t

    include Let_syntax2 with type ('a, 'e) t := ('a, 'e) t

    module Let_syntax : Let_syntax2 with type ('a, 'e) t := ('a, 'e) t
  end
end

module Make2 (X : Monad.Basic2) : S2 with type ('a, 'e) t := ('a, 'e) X.t =
struct
  include X
  module M = Monad.Make2 (X)
  module Let = M.Let_syntax.Let_syntax

  include (M : S_without_syntax2 with type ('a, 'e) t := ('a, 'e) t)

  module Let_syntax = struct
    include (M.Let_syntax : Base_syntax2 with type ('a, 'e) t := ('a, 'e) t)

    include (Let : Let_syntax2 with type ('a, 'e) t := ('a, 'e) t)

    module Let_syntax = Let
  end
end

module type Let_syntax3 = sig
  type ('a, 'd, 'e) t

  val return : 'a -> ('a, 'd, 'e) t

  val bind : ('a, 'd, 'e) t -> f:('a -> ('b, 'd, 'e) t) -> ('b, 'd, 'e) t

  val map : ('a, 'd, 'e) t -> f:('a -> 'b) -> ('b, 'd, 'e) t

  val both : ('a, 'd, 'e) t -> ('b, 'd, 'e) t -> ('a * 'b, 'd, 'e) t

  module Open_on_rhs : sig end
end

module type Base_syntax3 = sig
  type ('a, 'd, 'e) t

  val return : 'a -> ('a, 'd, 'e) t

  include Infix3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t
end

module type Syntax3 = sig
  include Base_syntax3

  include Let_syntax3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t
end

module type S_without_syntax3 = sig
  type ('a, 'd, 'e) t

  include Infix3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t

  module Monad_infix : Infix3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t

  val bind : ('a, 'd, 'e) t -> f:('a -> ('b, 'd, 'e) t) -> ('b, 'd, 'e) t

  val return : 'a -> ('a, _, _) t

  val map : ('a, 'd, 'e) t -> f:('a -> 'b) -> ('b, 'd, 'e) t

  val join : (('a, 'd, 'e) t, 'd, 'e) t -> ('a, 'd, 'e) t

  val ignore_m : (_, 'd, 'e) t -> (unit, 'd, 'e) t

  val all : ('a, 'd, 'e) t list -> ('a list, 'd, 'e) t

  val all_unit : (unit, 'd, 'e) t list -> (unit, 'd, 'e) t

  val all_ignore : (unit, 'd, 'e) t list -> (unit, 'd, 'e) t
    [@@deprecated "[since 2018-02] Use [all_unit]"]
end

module type S3 = sig
  type ('a, 'd, 'e) t

  include S_without_syntax3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t

  module Let_syntax : sig
    include Base_syntax3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t

    include Let_syntax3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t

    module Let_syntax : Let_syntax3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t
  end
end

module Make3 (X : Monad.Basic3) :
  S3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) X.t = struct
  include X
  module M = Monad.Make3 (X)
  module Let = M.Let_syntax.Let_syntax

  include (M : S_without_syntax3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t)

  module Let_syntax = struct
    include (
      M.Let_syntax : Base_syntax3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t )

    include (Let : Let_syntax3 with type ('a, 'd, 'e) t := ('a, 'd, 'e) t)

    module Let_syntax = Let
  end
end
