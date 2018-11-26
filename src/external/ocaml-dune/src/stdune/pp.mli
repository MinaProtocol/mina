(** Pretty printers *)

(** A document that is not yet rendered. The argument is the type of
    tags in the document. For instance tags might be used for
    styles. *)
type +'tag t

module type Tag = sig
  type t

  module Handler : sig
    type tag = t
    type t

    (** Initial tag handler *)
    val init : t

    (** Handle a tag: return the string that enables the tag, the
        handler while the tag is active and the string to disable the
        tag. *)
    val handle : t -> tag -> string * t * string
  end with type tag := t
end

module Renderer : sig
  module type S = sig
    module Tag : Tag

    val string
      :  unit
      -> (?margin:int -> ?tag_handler:Tag.Handler.t -> Tag.t t -> string)
           Staged.t
    val channel
      :  out_channel
      -> (?margin:int -> ?tag_handler:Tag.Handler.t -> Tag.t t -> unit)
           Staged.t
  end

  module Make(Tag : Tag) : S with module Tag = Tag
end

(** A simple renderer that doesn't take tags *)
module Render : Renderer.S
    with type Tag.t         = unit
    with type Tag.Handler.t = unit

val pp : Format.formatter -> unit t -> unit

val nop : 'a t
val seq : 'a t -> 'a t -> 'a t
val concat : 'a t list -> 'a t
val box : ?indent:int -> 'a t list -> 'a t
val vbox : ?indent:int -> 'a t list -> 'a t
val hbox : 'a t list -> 'a t
val hvbox : ?indent:int -> 'a t list -> 'a t
val hovbox : ?indent:int -> 'a t list -> 'a t

val int    : int    -> _ t
val string : string -> _ t
val char   : char   -> _ t
val list   : ?sep:'b t -> 'a list -> f:('a -> 'b t) -> 'b t

val space   : _ t
val cut     : _ t
val newline : _ t

val text : string -> _ t

val tag : 'a t -> tag:'a -> 'a t
