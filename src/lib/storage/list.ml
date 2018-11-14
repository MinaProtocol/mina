open Core_kernel
open Async_kernel

module Make (M : Storage_intf.With_checksum_intf) :
  Storage_intf.With_checksum_intf with type location = M.location list = struct
  type 'a t = unit

  type location = M.location list [@@deriving sexp]

  module Controller = M.Controller

  let errors errs =
    List.map errs ~f:(function
      | `Checksum_no_match -> Error.of_string "Checksum_no_match"
      | `IO_error e -> e
      | `No_exist -> Error.of_string "No_exist" )
    |> Error.of_list

  let first_success ~f =
    let open Deferred.Let_syntax in
    let rec go errs = function
      | [] -> return (Error (`IO_error (errors errs)))
      | x :: xs -> (
          match%bind f x with
          | Ok x -> return (Ok x)
          | Error e -> go (e :: errs) xs )
    in
    go []

  let load c loc = first_success loc ~f:(fun l -> M.load c l)

  let load_with_checksum c loc =
    first_success loc ~f:(fun l -> M.load_with_checksum c l)

  let store c loc x = M.store c (List.hd_exn loc) x

  let store_with_checksum c loc x = M.store_with_checksum c (List.hd_exn loc) x
end
