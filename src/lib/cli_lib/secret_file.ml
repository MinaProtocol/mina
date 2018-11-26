open Core
open Async

type password = Bytes.t Async.Deferred.Or_error.t Lazy.t

let handle_open ~mkdir ~(f : string -> 'a Deferred.Or_error.t) path :
    'a Deferred.Or_error.t =
  let open Unix.Error in
  let open Deferred.Or_error.Let_syntax in
  let dn = Filename.dirname path in
  let%bind parent_exists =
    let open Deferred.Let_syntax in
    match%bind
      Monitor.try_with ~extract_exn:true (fun () ->
          let%bind stat = Unix.stat dn in
          if stat.kind <> `Directory then
            Deferred.Or_error.errorf
              "%s exists and it not a directory, can't store files there" dn
          else Deferred.Or_error.return true )
    with
    | Ok x -> return x
    | Error (Unix.Unix_error (ENOENT, _, _)) -> Deferred.Or_error.return false
    | Error (Unix.Unix_error (e, _, _)) ->
        Deferred.Or_error.errorf "could not stat %s: %s, not making keys\n" dn
          (message e)
    | Error e -> Deferred.Or_error.of_exn e
  in
  let%bind () =
    let open Deferred.Let_syntax in
    match%bind
      Monitor.try_with ~extract_exn:true (fun () ->
          if (not parent_exists) && mkdir then
            let%bind () = Unix.mkdir ~p:() dn in
            let%bind () = Unix.chmod dn ~perm:0o700 in
            Deferred.Or_error.ok_unit
          else if not parent_exists then
            Deferred.Or_error.errorf
              "%s does not exist\nHint: mkdir -p %s; chmod 700 %s\n" dn dn dn
          else Deferred.Or_error.ok_unit )
    with
    | Ok x -> return x
    | Error (Unix.Unix_error ((EACCES as e), _, _)) ->
        Deferred.Or_error.errorf "could not mkdir -p %s: %s\n" dn (message e)
    | Error e -> raise e
  in
  match%bind
    Deferred.Or_error.try_with ~extract_exn:true (fun () -> f path)
  with
  | Ok x -> Deferred.Or_error.return x
  | Error e -> (
    (* (Unix.Unix_error (e, _, _)) -> *)
    match Error.to_exn e with
    | Unix.Unix_error (e, _, _) ->
        Deferred.Or_error.errorf "could not open %s: %s\n" path (message e)
    | e -> Deferred.Or_error.of_exn e )

let lift (t : 'a Deferred.t) : 'a Deferred.Or_error.t = t >>| fun x -> Ok x

let lift1 f x = lift (f x)

let write ~path ~mkdir ~(password : Bytes.t Deferred.Or_error.t Lazy.t)
    ~plaintext =
  let open Deferred.Or_error.Let_syntax in
  let%bind privkey_f =
    handle_open ~mkdir ~f:(fun path -> lift (Writer.open_file path)) path
  in
  let%bind password = Lazy.force password in
  let sb = Secret_box.encrypt ~plaintext ~password in
  let sb =
    Secret_box.to_yojson sb |> Yojson.Safe.to_string |> Bytes.of_string
  in
  Writer.write_bytes privkey_f sb ;
  let%bind () = lift (Unix.chmod path ~perm:0o600) in
  lift (Writer.close privkey_f)

let read ~path ~(password : Bytes.t Deferred.Or_error.t Lazy.t) =
  let open Deferred.Or_error.Let_syntax in
  let read_all r =
    lift (Pipe.to_list (Reader.lines r))
    >>| fun ss -> String.concat ~sep:"\n" ss
  in
  let%bind privkey_file =
    handle_open ~mkdir:false ~f:(lift1 Reader.open_file) path
  in
  let%bind st = handle_open ~mkdir:false ~f:(lift1 Unix.stat) path in
  let file_error =
    if st.perm land 0o077 <> 0 then
      Some
        (sprintf
           "insecure permissions on `%s`. They should be 0600, they are %o\n\
            Hint: chmod 600 %s\n"
           path (st.perm land 0o777) path)
    else None
  in
  let dn = Filename.dirname path in
  let%bind st = handle_open ~mkdir:false ~f:(lift1 Unix.stat) dn in
  let dir_error =
    if st.perm land 0o777 <> 0o700 then
      Some
        (sprintf
           "insecure permissions on `%s`. They should be 0700, they are %o\n\
            Hint: chmod 700 %s\n"
           dn (st.perm land 0o777) dn)
    else None
  in
  let%bind () =
    match (file_error, dir_error) with
    | Some e1, Some e2 -> Deferred.Or_error.error_string (e1 ^ e2)
    | Some e1, None | None, Some e1 -> Deferred.Or_error.error_string e1
    | None, None -> Deferred.Or_error.ok_unit
  in
  let%bind file_contents = read_all privkey_file in
  let%bind sb =
    match Secret_box.of_yojson (Yojson.Safe.from_string file_contents) with
    | Ok sb -> return sb
    | Error e ->
        Deferred.Or_error.errorf
          "couldn't parse %s, is the secret file corrupt?: %s\n" path e
  in
  let%bind password = Lazy.force password in
  match Secret_box.decrypt ~password sb with
  | Ok pk_bytes -> return pk_bytes
  | Error e ->
      Deferred.Or_error.errorf "while decrypting %s: %s\n" path
        (Error.to_string_hum e)
