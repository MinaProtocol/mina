open Ppxlib
open Asttypes

(* `log` reduces the boilerplate needed to call the logger

   Example usage:

     [%log info]
     [%log' info logger]

   expands to

     Logger.info logger ~module_:__MODULE__ ~location:__LOC__

   Notes:

     - if the logger is omitted, a variable `logger` must be in scope
     - if the log level is `spam`, the module and location are omitted

   The variants `%str_log` and `%str_log'` generate the module `Logger.Structured`
   instead of `Logger`.

*)

module type Ppxinfo = sig
  val name : string

  val logger_module : string
end

module Make (Info : Ppxinfo) = struct
  let prime s = s ^ "'"

  let expand_capture_logger ~loc ~path:_ (log_level : longident) =
    let module E = Ppxlib.Ast_builder.Make (struct
      let loc = loc
    end) in
    let open E in
    let level_name = Longident.name log_level in
    let log_level_id =
      Info.logger_module ^ "." ^ level_name |> Longident.parse
    in
    let log_level_expr = pexp_ident (Located.mk log_level_id) in
    (* spam logs don't contain module, location *)
    if String.equal level_name "spam" then [%expr [%e log_level_expr] logger]
    else
      [%expr [%e log_level_expr] logger ~module_:__MODULE__ ~location:__LOC__]

  let expand_explicit_logger ~loc ~path:_ (log_level : longident)
      (_, (logger : expression)) =
    let module E = Ppxlib.Ast_builder.Make (struct
      let loc = loc
    end) in
    let open E in
    let level_name = Longident.name log_level in
    let log_level_id =
      Info.logger_module ^ "." ^ level_name |> Longident.parse
    in
    let log_level_expr = pexp_ident (Located.mk log_level_id) in
    (* spam logs don't contain module, location *)
    if String.equal level_name "spam" then
      [%expr [%e log_level_expr] [%e logger]]
    else
      [%expr
        [%e log_level_expr] [%e logger] ~module_:__MODULE__ ~location:__LOC__]

  let ext_capture_logger =
    Extension.declare Info.name Extension.Context.expression
      Ast_pattern.(single_expr_payload (pexp_ident __))
      expand_capture_logger

  let ext_explicit_logger =
    Extension.declare (prime Info.name) Extension.Context.expression
      Ast_pattern.(
        pstr (pstr_eval (pexp_apply (pexp_ident __) (__ ^:: nil)) nil ^:: nil))
      expand_explicit_logger

  let () =
    Driver.register_transformation Info.name
      ~rules:[Context_free.Rule.extension ext_capture_logger]

  let () =
    Driver.register_transformation (prime Info.name)
      ~rules:[Context_free.Rule.extension ext_explicit_logger]
end

include Make (struct
  let name = "log"

  let logger_module = "Logger"
end)

include Make (struct
  let name = "str_log"

  let logger_module = "Logger.Structured"
end)
