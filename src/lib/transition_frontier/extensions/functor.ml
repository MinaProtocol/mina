open Async_kernel
open Pipe_lib

module Make_broadcasted (Extension : Intf.Extension_base_intf) :
  Intf.Broadcasted_extension_intf
    with type extension = Extension.t
     and type view = Extension.view = struct
  type extension = Extension.t

  type view = Extension.view

  type t =
    { extension : Extension.t
    ; writer : Extension.view Broadcast_pipe.Writer.t
    ; reader : Extension.view Broadcast_pipe.Reader.t
    }

  let extension { extension; _ } = extension

  let create (extension, initial_view) =
    let open Deferred.Let_syntax in
    let reader, writer = Broadcast_pipe.create initial_view in
    let%map () = Broadcast_pipe.Writer.write writer initial_view in
    { extension; reader; writer }

  let close { writer; _ } = Broadcast_pipe.Writer.close writer

  let peek { reader; _ } = Broadcast_pipe.Reader.peek reader

  let reader { reader; _ } = reader

  let update { extension; writer; _ } frontier diffs =
    match Extension.handle_diffs extension frontier diffs with
    | Some view ->
        Broadcast_pipe.Writer.write writer view
    | None ->
        Deferred.unit
end
