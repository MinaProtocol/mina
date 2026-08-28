open Core

(** The outcome of verifying a submission.

    [verified] and [validation_error] are two views of the same fact, so both
    are always emitted together from here: a submission is verified exactly
    when it carries no validation error. Building the two fields separately at
    each output site is what let them disagree, reporting [verified: true]
    alongside a proof failure. *)
module Verification_status = struct
  type t = Verified | Failed of string

  let of_or_error = function
    | Ok _ ->
        Verified
    | Error e ->
        Failed (Error.to_string_hum e)

  let to_json_fields = function
    | Verified ->
        [ ("verified", `Bool true); ("validation_error", `Null) ]
    | Failed e ->
        [ ("verified", `Bool false); ("validation_error", `String e) ]

  let to_cassandra_updates = function
    | Verified ->
        [ ("verified", "true"); ("validation_error", "NULL") ]
    | Failed e ->
        [ ("verified", "false"); ("validation_error", sprintf "'%s'" e) ]

  let%test_module "verified and validation_error cannot disagree" =
    ( module struct
      let statuses = [ Verified; Failed "(Pickles.verify dlog_check)" ]

      let field fields name =
        List.Assoc.find_exn fields name ~equal:String.equal

      let%test "json: verified is true exactly when there is no error" =
        List.for_all statuses ~f:(fun status ->
            let fields = to_json_fields status in
            let verified =
              match field fields "verified" with
              | `Bool b ->
                  b
              | _ ->
                  failwith "verified is not a boolean"
            in
            let no_error =
              match field fields "validation_error" with
              | `Null ->
                  true
              | _ ->
                  false
            in
            Bool.equal verified no_error )

      (* An absent validation_error column counts as no error: a caller reading
         the row cannot tell it from an explicit NULL. *)
      let%test "cassandra: verified is true exactly when there is no error" =
        List.for_all statuses ~f:(fun status ->
            let fields = to_cassandra_updates status in
            let no_error =
              match
                List.Assoc.find fields "validation_error" ~equal:String.equal
              with
              | None | Some "NULL" ->
                  true
              | Some _ ->
                  false
            in
            Bool.equal (String.equal (field fields "verified") "true") no_error )

      let%test "a failed submission reports its reason" =
        let fields = to_json_fields (Failed "(Pickles.verify dlog_check)") in
        match (field fields "verified", field fields "validation_error") with
        | `Bool false, `String "(Pickles.verify dlog_check)" ->
            true
        | _ ->
            false

      let%test "of_or_error carries the error text through" =
        match of_or_error (Error (Error.of_string "boom")) with
        | Failed "boom" ->
            true
        | Verified | Failed _ ->
            false
    end )
end
