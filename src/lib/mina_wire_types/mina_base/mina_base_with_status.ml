module V2 = struct
  type 'a t = { data : 'a; status : Mina_base_transaction_status.V3.t }
end
