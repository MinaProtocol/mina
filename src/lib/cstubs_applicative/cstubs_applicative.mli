module Types = Cstubs.Types

module type FOREIGN = Ctypes.FOREIGN

module type BINDINGS = functor
  (F : sig
     type 'a fn

     type 'a return

     val ( @-> ) : 'a Ctypes.typ -> 'b fn -> ('a -> 'b) fn

     val returning : 'a Ctypes.typ -> 'a return fn

     type 'a result = unit

     val foreign : string -> ('a -> 'b) fn -> unit

     val foreign_value : string -> 'a Ctypes.typ -> unit
   end)
  -> sig end

type errno_policy = Cstubs.errno_policy

val ignore_errno : errno_policy

val return_errno : errno_policy

type concurrency_policy = Cstubs.concurrency_policy

val sequential : concurrency_policy

val unlocked : concurrency_policy

val lwt_preemptive : concurrency_policy

val lwt_jobs : concurrency_policy

module type Applicative_with_let = sig
  type 'a t

  val return : 'a -> 'a t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val both : 'a t -> 'b t -> ('a * 'b) t

  val ( <*> ) : ('a -> 'b) t -> 'a t -> 'b t

  val ( <* ) : 'a t -> unit t -> 'a t

  val ( *> ) : unit t -> 'a t -> 'a t

  val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

  val apply : ('a -> 'b) t -> 'a t -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t

  val map3 : 'a t -> 'b t -> 'c t -> f:('a -> 'b -> 'c -> 'd) -> 'd t

  val all : 'a t list -> 'a list t

  val all_unit : unit t list -> unit t

  module Applicative_infix : sig
    val ( <*> ) : ('a -> 'b) t -> 'a t -> 'b t

    val ( <* ) : 'a t -> unit t -> 'a t

    val ( *> ) : unit t -> 'a t -> 'a t

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t
  end

  module Open_on_rhs_intf : sig
    module type S
  end

  module Let_syntax : sig
    val return : 'a -> 'a t

    val ( <*> ) : ('a -> 'b) t -> 'a t -> 'b t

    val ( <* ) : 'a t -> unit t -> 'a t

    val ( *> ) : unit t -> 'a t -> 'a t

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    module Let_syntax : sig
      val return : 'a -> 'a t

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val both : 'a t -> 'b t -> ('a * 'b) t

      module Open_on_rhs : Open_on_rhs_intf.S
    end
  end
end

module Make_applicative_with_let : functor (X : Base.Applicative.Basic) -> sig
  val return : 'a -> 'a X.t

  val map : 'a X.t -> f:('a -> 'b) -> 'b X.t

  val both : 'a X.t -> 'b X.t -> ('a * 'b) X.t

  val ( <*> ) : ('a -> 'b) X.t -> 'a X.t -> 'b X.t

  val ( <* ) : 'a X.t -> unit X.t -> 'a X.t

  val ( *> ) : unit X.t -> 'a X.t -> 'a X.t

  val ( >>| ) : 'a X.t -> ('a -> 'b) -> 'b X.t

  val apply : ('a -> 'b) X.t -> 'a X.t -> 'b X.t

  val map2 : 'a X.t -> 'b X.t -> f:('a -> 'b -> 'c) -> 'c X.t

  val map3 : 'a X.t -> 'b X.t -> 'c X.t -> f:('a -> 'b -> 'c -> 'd) -> 'd X.t

  val all : 'a X.t list -> 'a list X.t

  val all_unit : unit X.t list -> unit X.t

  module Applicative_infix : sig
    val ( <*> ) : ('a -> 'b) X.t -> 'a X.t -> 'b X.t

    val ( <* ) : 'a X.t -> unit X.t -> 'a X.t

    val ( *> ) : unit X.t -> 'a X.t -> 'a X.t

    val ( >>| ) : 'a X.t -> ('a -> 'b) -> 'b X.t
  end

  module Open_on_rhs_intf : sig
    module type S
  end

  module Let_syntax : sig
    val return : 'a -> 'a X.t

    val ( <*> ) : ('a -> 'b) X.t -> 'a X.t -> 'b X.t

    val ( <* ) : 'a X.t -> unit X.t -> 'a X.t

    val ( *> ) : unit X.t -> 'a X.t -> 'a X.t

    val ( >>| ) : 'a X.t -> ('a -> 'b) -> 'b X.t

    module Let_syntax : sig
      val return : 'a -> 'a X.t

      val map : 'a X.t -> f:('a -> 'b) -> 'b X.t

      val both : 'a X.t -> 'b X.t -> ('a * 'b) X.t

      module Open_on_rhs : Open_on_rhs_intf.S
    end
  end
end

module Applicative_unit : sig
  val return : 'a -> Base.unit

  val map : Base.unit -> f:('a -> 'b) -> Base.unit

  val both : Base.unit -> Base.unit -> Base.unit

  val ( <*> ) : Base.unit -> Base.unit -> Base.unit

  val ( <* ) : Base.unit -> Base.unit -> Base.unit

  val ( *> ) : Base.unit -> Base.unit -> Base.unit

  val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit

  val apply : Base.unit -> Base.unit -> Base.unit

  val map2 : Base.unit -> Base.unit -> f:('a -> 'b -> 'c) -> Base.unit

  val map3 :
    Base.unit -> Base.unit -> Base.unit -> f:('a -> 'b -> 'c -> 'd) -> Base.unit

  val all : Base.unit list -> Base.unit

  val all_unit : Base.unit list -> Base.unit

  module Applicative_infix : sig
    val ( <*> ) : Base.unit -> Base.unit -> Base.unit

    val ( <* ) : Base.unit -> Base.unit -> Base.unit

    val ( *> ) : Base.unit -> Base.unit -> Base.unit

    val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit
  end

  module Open_on_rhs_intf : sig
    module type S
  end

  module Let_syntax : sig
    val return : 'a -> Base.unit

    val ( <*> ) : Base.unit -> Base.unit -> Base.unit

    val ( <* ) : Base.unit -> Base.unit -> Base.unit

    val ( *> ) : Base.unit -> Base.unit -> Base.unit

    val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit

    module Let_syntax : sig
      val return : 'a -> Base.unit

      val map : Base.unit -> f:('a -> 'b) -> Base.unit

      val both : Base.unit -> Base.unit -> Base.unit

      module Open_on_rhs : Open_on_rhs_intf.S
    end
  end
end

module Applicative_id : sig
  val return : 'a -> 'a

  val map : 'a -> f:('a -> 'b) -> 'b

  val both : 'a -> 'b -> 'a * 'b

  val ( <*> ) : ('a -> 'b) -> 'a -> 'b

  val ( <* ) : 'a -> unit -> 'a

  val ( *> ) : unit -> 'a -> 'a

  val ( >>| ) : 'a -> ('a -> 'b) -> 'b

  val apply : ('a -> 'b) -> 'a -> 'b

  val map2 : 'a -> 'b -> f:('a -> 'b -> 'c) -> 'c

  val map3 : 'a -> 'b -> 'c -> f:('a -> 'b -> 'c -> 'd) -> 'd

  val all : 'a list -> 'a list

  val all_unit : unit list -> unit

  module Applicative_infix : sig
    val ( <*> ) : ('a -> 'b) -> 'a -> 'b

    val ( <* ) : 'a -> unit -> 'a

    val ( *> ) : unit -> 'a -> 'a

    val ( >>| ) : 'a -> ('a -> 'b) -> 'b
  end

  module Open_on_rhs_intf : sig
    module type S
  end

  module Let_syntax : sig
    val return : 'a -> 'a

    val ( <*> ) : ('a -> 'b) -> 'a -> 'b

    val ( <* ) : 'a -> unit -> 'a

    val ( *> ) : unit -> 'a -> 'a

    val ( >>| ) : 'a -> ('a -> 'b) -> 'b

    module Let_syntax : sig
      val return : 'a -> 'a

      val map : 'a -> f:('a -> 'b) -> 'b

      val both : 'a -> 'b -> 'a * 'b

      module Open_on_rhs : Open_on_rhs_intf.S
    end
  end
end

module type Foreign_applicative = sig
  type 'a fn

  type 'a return

  val ( @-> ) : 'a Ctypes.typ -> 'b fn -> ('a -> 'b) fn

  val returning : 'a Ctypes.typ -> 'a return fn

  type 'a result

  val foreign : string -> ('a -> 'b) fn -> ('a -> 'b) result

  val foreign_value : string -> 'a Ctypes.typ -> 'a Ctypes.ptr result

  val return : 'a -> 'a result

  val map : 'a result -> f:('a -> 'b) -> 'b result

  val both : 'a result -> 'b result -> ('a * 'b) result

  val ( <*> ) : ('a -> 'b) result -> 'a result -> 'b result

  val ( <* ) : 'a result -> unit result -> 'a result

  val ( *> ) : unit result -> 'a result -> 'a result

  val ( >>| ) : 'a result -> ('a -> 'b) -> 'b result

  val apply : ('a -> 'b) result -> 'a result -> 'b result

  val map2 : 'a result -> 'b result -> f:('a -> 'b -> 'c) -> 'c result

  val map3 :
    'a result -> 'b result -> 'c result -> f:('a -> 'b -> 'c -> 'd) -> 'd result

  val all : 'a result list -> 'a list result

  val all_unit : unit result list -> unit result

  module Applicative_infix : sig
    val ( <*> ) : ('a -> 'b) result -> 'a result -> 'b result

    val ( <* ) : 'a result -> unit result -> 'a result

    val ( *> ) : unit result -> 'a result -> 'a result

    val ( >>| ) : 'a result -> ('a -> 'b) -> 'b result
  end

  module Open_on_rhs_intf : sig
    module type S
  end

  module Let_syntax : sig
    val return : 'a -> 'a result

    val ( <*> ) : ('a -> 'b) result -> 'a result -> 'b result

    val ( <* ) : 'a result -> unit result -> 'a result

    val ( *> ) : unit result -> 'a result -> 'a result

    val ( >>| ) : 'a result -> ('a -> 'b) -> 'b result

    module Let_syntax : sig
      val return : 'a -> 'a result

      val map : 'a result -> f:('a -> 'b) -> 'b result

      val both : 'a result -> 'b result -> ('a * 'b) result

      module Open_on_rhs : Open_on_rhs_intf.S
    end
  end

  val map_return : 'a return -> f:('a -> 'b) -> 'b return

  val bind_return : 'a return -> f:('a -> 'b return) -> 'b
end

module type Bindings_with_applicative = functor
  (F : sig
     type 'a fn

     type 'a return

     val ( @-> ) : 'a Ctypes.typ -> 'b fn -> ('a -> 'b) fn

     val returning : 'a Ctypes.typ -> 'a return fn

     type 'a result = Base.unit

     val foreign : string -> ('a -> 'b) fn -> Base.unit

     val foreign_value : string -> 'a Ctypes.typ -> Base.unit

     val return : 'a -> Base.unit

     val map : Base.unit -> f:('a -> 'b) -> Base.unit

     val both : Base.unit -> Base.unit -> Base.unit

     val ( <*> ) : Base.unit -> Base.unit -> Base.unit

     val ( <* ) : Base.unit -> Base.unit -> Base.unit

     val ( *> ) : Base.unit -> Base.unit -> Base.unit

     val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit

     val apply : Base.unit -> Base.unit -> Base.unit

     val map2 : Base.unit -> Base.unit -> f:('a -> 'b -> 'c) -> Base.unit

     val map3 :
          Base.unit
       -> Base.unit
       -> Base.unit
       -> f:('a -> 'b -> 'c -> 'd)
       -> Base.unit

     val all : Base.unit list -> Base.unit

     val all_unit : Base.unit list -> Base.unit

     module Applicative_infix : sig
       val ( <*> ) : Base.unit -> Base.unit -> Base.unit

       val ( <* ) : Base.unit -> Base.unit -> Base.unit

       val ( *> ) : Base.unit -> Base.unit -> Base.unit

       val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit
     end

     module Open_on_rhs_intf : sig
       module type S
     end

     module Let_syntax : sig
       val return : 'a -> Base.unit

       val ( <*> ) : Base.unit -> Base.unit -> Base.unit

       val ( <* ) : Base.unit -> Base.unit -> Base.unit

       val ( *> ) : Base.unit -> Base.unit -> Base.unit

       val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit

       module Let_syntax : sig
         val return : 'a -> Base.unit

         val map : Base.unit -> f:('a -> 'b) -> Base.unit

         val both : Base.unit -> Base.unit -> Base.unit

         module Open_on_rhs : Open_on_rhs_intf.S
       end
     end

     val map_return : 'a return -> f:('a -> 'b) -> 'b return

     val bind_return : 'a return -> f:('a -> 'b return) -> 'b
   end)
  -> sig end

module Make_applicative_unit : functor
  (F : sig
     type 'a fn

     type 'a return

     val ( @-> ) : 'a Ctypes.typ -> 'b fn -> ('a -> 'b) fn

     val returning : 'a Ctypes.typ -> 'a return fn

     type 'a result = Base.unit

     val foreign : string -> ('a -> 'b) fn -> Base.unit

     val foreign_value : string -> 'a Ctypes.typ -> Base.unit
   end)
  -> sig
  type 'a fn

  type 'a return

  val ( @-> ) : 'a Ctypes.typ -> 'b fn -> ('a -> 'b) fn

  val returning : 'a Ctypes.typ -> 'a return fn

  type 'a result = Base.unit

  val foreign : string -> ('a -> 'b) fn -> Base.unit

  val foreign_value : string -> 'a Ctypes.typ -> Base.unit

  val return : 'a -> Base.unit

  val map : Base.unit -> f:('a -> 'b) -> Base.unit

  val both : Base.unit -> Base.unit -> Base.unit

  val ( <*> ) : Base.unit -> Base.unit -> Base.unit

  val ( <* ) : Base.unit -> Base.unit -> Base.unit

  val ( *> ) : Base.unit -> Base.unit -> Base.unit

  val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit

  val apply : Base.unit -> Base.unit -> Base.unit

  val map2 : Base.unit -> Base.unit -> f:('a -> 'b -> 'c) -> Base.unit

  val map3 :
    Base.unit -> Base.unit -> Base.unit -> f:('a -> 'b -> 'c -> 'd) -> Base.unit

  val all : Base.unit list -> Base.unit

  val all_unit : Base.unit list -> Base.unit

  module Applicative_infix : sig
    val ( <*> ) : Base.unit -> Base.unit -> Base.unit

    val ( <* ) : Base.unit -> Base.unit -> Base.unit

    val ( *> ) : Base.unit -> Base.unit -> Base.unit

    val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit
  end

  module Open_on_rhs_intf : sig
    module type S
  end

  module Let_syntax : sig
    val return : 'a -> Base.unit

    val ( <*> ) : Base.unit -> Base.unit -> Base.unit

    val ( <* ) : Base.unit -> Base.unit -> Base.unit

    val ( *> ) : Base.unit -> Base.unit -> Base.unit

    val ( >>| ) : Base.unit -> ('a -> 'b) -> Base.unit

    module Let_syntax : sig
      val return : 'a -> Base.unit

      val map : Base.unit -> f:('a -> 'b) -> Base.unit

      val both : Base.unit -> Base.unit -> Base.unit

      module Open_on_rhs : Open_on_rhs_intf.S
    end
  end

  val map_return : 'a return -> f:('a -> 'b) -> 'b return

  val bind_return : 'a return -> f:('a -> 'b return) -> 'b
end

module Make_applicative_id : functor
  (F : sig
     type 'a fn

     type 'a return = 'a

     val ( @-> ) : 'a Ctypes.typ -> 'b fn -> ('a -> 'b) fn

     val returning : 'a Ctypes.typ -> 'a fn

     type 'a result = 'a

     val foreign : string -> ('a -> 'b) fn -> 'a -> 'b

     val foreign_value : string -> 'a Ctypes.typ -> 'a Ctypes.ptr
   end)
  -> sig
  type 'a fn

  type 'a return = 'a

  val ( @-> ) : 'a Ctypes.typ -> 'b fn -> ('a -> 'b) fn

  val returning : 'a Ctypes.typ -> 'a fn

  type 'a result = 'a

  val foreign : string -> ('a -> 'b) fn -> 'a -> 'b

  val foreign_value : string -> 'a Ctypes.typ -> 'a Ctypes.ptr

  val return : 'a -> 'a

  val map : 'a -> f:('a -> 'b) -> 'b

  val both : 'a -> 'b -> 'a * 'b

  val ( <*> ) : ('a -> 'b) -> 'a -> 'b

  val ( <* ) : 'a -> unit -> 'a

  val ( *> ) : unit -> 'a -> 'a

  val ( >>| ) : 'a -> ('a -> 'b) -> 'b

  val apply : ('a -> 'b) -> 'a -> 'b

  val map2 : 'a -> 'b -> f:('a -> 'b -> 'c) -> 'c

  val map3 : 'a -> 'b -> 'c -> f:('a -> 'b -> 'c -> 'd) -> 'd

  val all : 'a list -> 'a list

  val all_unit : unit list -> unit

  module Applicative_infix : sig
    val ( <*> ) : ('a -> 'b) -> 'a -> 'b

    val ( <* ) : 'a -> unit -> 'a

    val ( *> ) : unit -> 'a -> 'a

    val ( >>| ) : 'a -> ('a -> 'b) -> 'b
  end

  module Open_on_rhs_intf : sig
    module type S
  end

  module Let_syntax : sig
    val return : 'a -> 'a

    val ( <*> ) : ('a -> 'b) -> 'a -> 'b

    val ( <* ) : 'a -> unit -> 'a

    val ( *> ) : unit -> 'a -> 'a

    val ( >>| ) : 'a -> ('a -> 'b) -> 'b

    module Let_syntax : sig
      val return : 'a -> 'a

      val map : 'a -> f:('a -> 'b) -> 'b

      val both : 'a -> 'b -> 'a * 'b

      module Open_on_rhs : Open_on_rhs_intf.S
    end
  end

  val map_return : 'a -> f:('a -> 'b) -> 'b

  val bind_return : 'a -> f:('a -> 'b) -> 'b
end

module Make_cstubs_bindings : functor
  (B : Bindings_with_applicative)
  (F : sig
     type 'a fn

     type 'a return

     val ( @-> ) : 'a Ctypes.typ -> 'b fn -> ('a -> 'b) fn

     val returning : 'a Ctypes.typ -> 'a return fn

     type 'a result = Base.unit

     val foreign : string -> ('a -> 'b) fn -> Base.unit

     val foreign_value : string -> 'a Ctypes.typ -> Base.unit
   end)
  -> sig end

val make_bindings : (module Bindings_with_applicative) -> (module BINDINGS)

val write_c :
     ?concurrency:concurrency_policy
  -> ?errno:errno_policy
  -> Format.formatter
  -> prefix:string
  -> (module Bindings_with_applicative)
  -> unit

val write_ml :
     ?concurrency:concurrency_policy
  -> ?errno:errno_policy
  -> Format.formatter
  -> prefix:string
  -> (module Bindings_with_applicative)
  -> unit
