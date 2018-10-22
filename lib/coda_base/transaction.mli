include Coda_spec.Transaction_intf.S
  with module Valid_payment = Payment.With_valid_signature
   and module Fee_transfer = Fee_transfer
   and module Coinbase = Coinbase
