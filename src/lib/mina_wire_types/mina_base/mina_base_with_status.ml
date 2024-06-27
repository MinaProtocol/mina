module V2 = struct
  type 'a t = { data : 'a; status : Mina_base_transaction_status.V2.t }
end
