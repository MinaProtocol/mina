(** Mina Rosetta client library.

    Thin HTTP client and typed Rosetta API surface, used by
    [rosetta-client] (the generic CLI).

    {[
      open Async

      let client =
        Rosetta_client.Http.create
          ~base_uri:(Uri.of_string "http://localhost:3087") ()

      let%bind status = Rosetta_client.Data.network_status client
    ]} *)

module Defaults = Defaults
module Http = Http
module Data = Data
module Models = Rosetta_models
