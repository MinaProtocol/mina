(** Mina Rosetta client library.

    Thin HTTP client, typed Rosetta API surface, and embedded
    rosetta-cli config accessors.  Used by both [rosetta-client]
    (the generic CLI) and [rosetta-healthcheck] (which only
    exposes readiness probes).

    {[
      open Async

      let client =
        Rosetta_client.Http.create
          ~base_uri:(Uri.of_string "http://localhost:3087") ()

      let%bind status = Rosetta_client.Data.network_status client
    ]} *)

module Http = Http
module Data = Data
module Construction = Construction
module Config = Config
module Errors = Errors
module Models = Rosetta_models
