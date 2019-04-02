open Core
open Coda_base

module Make (Inputs : Transition_frontier.Inputs_intf) = struct
  module Schema = Transition_database_schema.Make (Inputs)
  include Rocksdb.Serializable.GADT.Make (Schema)

  let get (type a) transition_storage ~logger ?(location = __LOC__)
      (key : a Schema.t) : a =
    match get transition_storage ~key with
    | Some value -> value
    | None -> (
        let log_error = Logger.error logger ~module_:__MODULE__ ~location in
        match key with
        | Transition hash ->
            log_error
              ~metadata:[("hash", State_hash.to_yojson hash)]
              "Could not retrieve external transition: $hash !" ;
            raise (Not_found_s ([%sexp_of: State_hash.t] hash))
        | Root ->
            log_error "Could not retrieve root" ;
            failwith "Could not retrieve root" )
end
