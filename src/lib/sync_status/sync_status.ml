open Core_kernel

let to_string = function
  | `Offline ->
      "Offline"
  | `Bootstrap ->
      "Bootstrap"
  | `Synced ->
      "Synced"
  | `Connecting ->
      "Connecting"
  | `Listening ->
      "Listening"

let of_string string =
  match String.lowercase string with
  | "offline" ->
      Ok `Offline
  | "bootstrap" ->
      Ok `Bootstrap
  | "synced" ->
      Ok `Synced
  | "connecting" ->
      Ok `Connecting
  | "listening" ->
      Ok `Listening
  | status ->
      Error (Error.createf !"%s is not a valid status" status)

let to_yojson status = `String (to_string status)

module Stable = struct
  module V1 = struct
    module T = struct
      type t = [`Offline | `Bootstrap | `Synced | `Connecting | `Listening]
      [@@deriving bin_io, version, sexp, hash, compare, equal]

      let to_yojson = to_yojson
    end

    include T
    include Hashable.Make (T)
  end

  module Latest = V1
end

type t = [`Offline | `Bootstrap | `Synced | `Connecting | `Listening]
[@@deriving sexp, hash, equal]

include Hashable.Make (Stable.Latest.T)

let%test "of_string (to_string x) == x" =
  List.for_all [`Offline; `Bootstrap; `Synced; `Connecting; `Listening]
    ~f:(fun sync_status ->
      equal sync_status (of_string (to_string sync_status) |> Or_error.ok_exn)
  )
