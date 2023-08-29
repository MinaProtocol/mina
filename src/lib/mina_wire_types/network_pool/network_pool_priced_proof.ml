module V1 = struct
  type 'proof t = { proof : 'proof; fee : Mina_base.Fee_with_prover.V1.t }
end
