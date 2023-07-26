module V1 = struct
  type ('a, 'field) t = { elt : 'a; stack_hash : 'field }
end
