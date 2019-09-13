module Ast : sig
  type t
end

module Parser : sig
  val parse : string -> (Ast.t, string) result
end

module Interpreter : sig
  val matches : Ast.t -> Yojson.Safe.t -> bool
end
