module type ENDPOINT = sig
  type t
  
  val uri : string
  val query : Yojson.Safe.t
  val of_json : Yojson.t -> (t, exn) Result.t
  val to_string : t -> string
end

val call :
  conf:Conf.t ->
  (module ENDPOINT with type t = 'a) ->
  ('a, exn) Async.Deferred.Result.t

val call_and_display :
  conf:Conf.t ->
  (module ENDPOINT with type t = 'a) ->
  unit ->
  unit Async.Deferred.t
