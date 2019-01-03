open Base

module Functor = struct
  module type S = sig
    type 'a t

    val map : 'a t -> f:('a -> 'b) -> 'b t
  end

  module type S2 = sig
    type ('a, 'e) t

    val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t
  end

  module type S3 = sig
    type ('a, 'x, 'y) t

    val map : ('a, 'x, 'y) t -> f:('a -> 'b) -> ('b, 'x, 'y) t
  end
end

module Make (F : Functor.S) : sig
  type 'a t = Pure of 'a | Free of 'a t F.t

  include Monad.S with type 'a t := 'a t
end = struct
  module T = struct
    type 'a t = Pure of 'a | Free of 'a t F.t

    let rec map t ~f =
      match t with
      | Pure x -> Pure (f x)
      | Free tf -> Free (F.map tf ~f:(map ~f))

    let map = `Custom map

    let return x = Pure x

    let rec bind t ~f =
      match t with Pure x -> f x | Free tf -> Free (F.map tf ~f:(bind ~f))
  end

  include T
  include Monad.Make (T)
end

module Make2 (F : Functor.S2) : sig
  type ('a, 'x) t = Pure of 'a | Free of (('a, 'x) t, 'x) F.t

  include Monad.S2 with type ('a, 'x) t := ('a, 'x) t
end = struct
  module T = struct
    type ('a, 'x) t = Pure of 'a | Free of (('a, 'x) t, 'x) F.t

    let rec map t ~f =
      match t with
      | Pure x -> Pure (f x)
      | Free tf -> Free (F.map tf ~f:(map ~f))

    let map = `Custom map

    let return x = Pure x

    let rec bind t ~f =
      match t with Pure x -> f x | Free tf -> Free (F.map tf ~f:(bind ~f))
  end

  include T
  include Monad.Make2 (T)
end

module Make3 (F : Functor.S3) : sig
  type ('a, 'x, 'y) t = Pure of 'a | Free of (('a, 'x, 'y) t, 'x, 'y) F.t

  include Monad.S3 with type ('a, 'x, 'y) t := ('a, 'x, 'y) t
end = struct
  module T = struct
    type ('a, 'x, 'y) t = Pure of 'a | Free of (('a, 'x, 'y) t, 'x, 'y) F.t

    let rec map t ~f =
      match t with
      | Pure x -> Pure (f x)
      | Free tf -> Free (F.map tf ~f:(map ~f))

    let map = `Custom map

    let return x = Pure x

    let rec bind t ~f =
      match t with Pure x -> f x | Free tf -> Free (F.map tf ~f:(bind ~f))
  end

  include T
  include Monad.Make3 (T)
end
