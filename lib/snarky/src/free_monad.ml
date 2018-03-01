open Base

module type Functor_intf = sig
  type 'a t

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

module Make(F : Functor_intf) : sig
  type 'a t =
    | Pure of 'a
    | Free of 'a t F.t

  include Monad.S with type 'a t := 'a t
end = struct
  module T = struct
    type 'a t =
      | Pure of 'a
      | Free of 'a t F.t

    let rec map t ~f =
      match t with
      | Pure x -> Pure (f x)
      | Free tf -> Free (F.map tf ~f:(map ~f))
    ;;

    let map = `Custom map

    let return x = Pure x

    let rec bind t ~f =
      match t with
      | Pure x -> f x
      | Free tf -> Free (F.map tf ~f:(bind ~f))
    ;;
  end

  include T
  include Monad.Make(T)
end

