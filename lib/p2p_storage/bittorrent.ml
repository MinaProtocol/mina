open Core_kernel
open Cohttp_async
open Async
open Logger

module Handle = struct
  type t = {magnet: string} [@@deriving bin_io]
end

module Session = struct
  module Config = struct
    type t = {helper_path: string; port: int option; datadir: string; upload_limit: int; download_limit: int; parent_logger: Logger.t}
    [@@deriving_make]
  end

  type t = {port: int; datadir: string; process: Process.t; log: Logger.t}

  module Report = struct
    type t = {chosen_port: int} [@@deriving sexp]
  end

  module PConfig = struct
    (* ul/dl limit is in "amortized content bytes/sec". bursts of up to 256KiB will
    occur unconditionally, but they won't happen faster than the ul/dl limit
    allows. this doesn't count any protocol overhead, it's purely about transferring
    torrent content. *)
    type t =
      { datadir: string
      ; upload_limit: int
      ; download_limit: int
      } [@@deriving sexp]
  end

  let create {Config.helper_path; port; datadir; upload_limit; download_limit; parent_logger} =
    let port_args =
      match port with Some p -> ["--port"; Int.to_string p] | None -> []
    in
    let%bind process = Process.create_exn ~prog:helper_path ~args:port_args () in
    let%bind report =
      Writer.write_sexp ~terminate_with:Newline (Process.stdin process) (PConfig.sexp_of_t {datadir; upload_limit; download_limit}) ;
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
  let%bind () = Unix.mkdir fullpath in
  let%bind () = write_file (Filename.concat fullpath "blob_content") data in
  let url =
    Printf.sprintf "http://localhost:%d/offer?subdir=%s" self.port hash
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
  if resp.status = `OK then Reader.file_contents fullpath >>| Or_error.return
  else
    Deferred.return (Or_error.error_string "some error")

let forget (self: Session.t) {Handle.magnet} : unit Deferred.t =
  let url =
    Printf.sprintf "http://localhost:%d/forget?magnet=%s" self.port
      (Uri.pct_encode magnet)
  in
  let%map _ = Client.post (Uri.of_string url) in ()
