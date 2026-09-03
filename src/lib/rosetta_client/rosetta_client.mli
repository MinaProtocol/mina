(** Mina Rosetta client library.

    Thin HTTP client and typed Rosetta API surface, shared by
    [rosetta-client] (the generic CLI) and [rosetta-healthcheck] (which
    only exposes readiness probes).

    {[
      open Async

      let client =
        Rosetta_client.Http.create
          ~base_uri:(Uri.of_string "http://localhost:3087") ()

      let%bind status = Rosetta_client.Data.network_status client
    ]} *)

module Defaults = Defaults
module Flags = Flags
module Http = Http
module Data = Data
module Models = Rosetta_models
