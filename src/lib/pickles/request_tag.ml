type (_, _) t = ..

module type S = sig
  type var

  type value

  type (_, _) t += T : (var, value) t
end

module F = struct
  type ('var, 'value) t =
    (module S with type var = 'var
               and type value = 'value)
end

let create : type var value. unit -> (var, value) F.t =
 fun () ->
  ( module struct
    type nonrec var = var

    type nonrec value = value

    type (_, _) t += T : (var, value) t
  end )
