exception Mina_user_error of { message : string; where : string option }

let raisef ?where =
  Format.ksprintf (fun message -> raise (Mina_user_error { message; where }))

let raise ?where message = raise (Mina_user_error { message; where })

let () =
  Stdlib.Printexc.register_printer (fun exn ->
      match exn with
      | Mina_user_error { message; where } ->
          let error =
            match where with
            | None ->
                "encountered a configuration error"
            | Some where ->
                Printf.sprintf "encountered a configuration error %s" where
          in
          Some
            (Printf.sprintf {err|
FATAL ERROR

  ☠  Mina %s.

  %s
%!|err} error
               message )
      | _ ->
          None )
