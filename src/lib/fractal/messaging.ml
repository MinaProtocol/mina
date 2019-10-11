module F(Message : sig type (_, _) t end) = struct
  type ('k, 'env) t =
    | Send_and_receive
        (* Interactive *) :
        ('q, 'env) Type.t * 'q * ('r, 'env) Message.t * ('r -> 'k)
        -> ('k, 'env) t

  let map : type a b e. (a, e) t -> f:(a -> b) -> (b, e) t =
    fun t ~f ->
    let cont k x = f (k x) in
    match t with
    | Send_and_receive (t_q, q, t_r, k) ->
        Send_and_receive (t_q, q, t_r, cont k)
end

