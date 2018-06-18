open Core_kernel
open Cohttp_async
open Async
open Logger

module Handle = struct
  type t = {magnet: string} [@@deriving bin_io]
end

module Session = struct
  module Config = struct
    type t = {path: string; port: int option; datadir: string; parent_logger: Logger.t}
    [@@deriving_make]
  end

  type t = {port: int; datadir: string; process: Process.t; log: Logger.t}

  module Report = struct
    type t = {chosen_port: int} [@@deriving sexp]
  end

  let create {Config.path; port; datadir; parent_logger} =
    let port_args =
      match port with Some p -> ["--port"; Int.to_string p] | None -> []
    in
    let%bind process = Process.create_exn ~prog:path ~args:port_args () in
    let%bind report =
      match%map Process.stdout process |> Reader.read_sexp with
      | `Ok sexp -> Report.t_of_sexp sexp
      | `Eof -> failwith "figure out error handling"
    in
    let port = report.Report.chosen_port in
    let log = Logger.child parent_logger "bittorrent session" in
    Deferred.Or_error.return {process; port; datadir; log}
end

let write_file name contents =
  let%bind writer = Writer.open_file name in
  Writer.write_bigstring writer (Bigstring.of_string contents) ;
  Writer.close writer

let offer (self: Session.t) data : Handle.t Deferred.Or_error.t =
  let hash = Md5.digest_string data |> Md5.to_hex in
  let fullpath = Filename.concat self.datadir hash in
  let%bind () = write_file fullpath data in
  let url =
    Printf.sprintf "http://localhost:%d/offer?fullpath=%s" self.port
      (Uri.pct_encode fullpath)
  in
  let () = Logger.info self.log "jeez" in
  let%bind resp, body = Client.post (Uri.of_string url) in
  let%bind s = Body.to_string body in
  if resp.status = `OK then Deferred.Or_error.return {Handle.magnet= s}
  else
    let%bind () = Unix.unlink fullpath in
    Deferred.return (Or_error.error_string "couldn't offer, subprocess is dead?")

module Retrieved = struct

end

let retrieve (self: Session.t) {Handle.magnet} : string Deferred.Or_error.t =
  let url =
    Printf.sprintf "http://localhost:%d/retrieve?magnet=%s" self.port
      (Uri.pct_encode magnet)
  in
  let%bind resp, body = Client.get (Uri.of_string url) in
  let%bind fullpath = Body.to_string body in
  if resp.status = `OK then Deferred.Or_error.return (Reader.file_contents fullpath)
  else
    Deferred.return (Or_error.error_string "some error")

let forget (self: Session.t) {Handle.magnet} : unit Deferred.t =
  let url =
    Printf.sprintf "http://localhost:%d/forget?magnet=%s" self.port
      (Uri.pct_encode magnet)
  in
  let%map _ = Client.post (Uri.of_string url) in ()
