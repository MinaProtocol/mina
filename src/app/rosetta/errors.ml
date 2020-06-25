open Core

let create ?(code = 400) ?(retriable = true) message =
  `Error {Models.Error.code= Int32.of_int_exn code; message; retriable}
