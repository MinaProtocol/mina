open Tc;

/// The CallTable is used to bridge the world of a single event listener with
/// the world of tasks.
///
/// Given type witnesses for the different kinds of Tasks you wish to
/// bootstrap, CallTable can generate `Pending.t('x, 'a)`, or tasks coupled
/// with an identifier that you can feed later to resolve the underlying task.

module Make:
  (
    Typ: {
      /// All witnesses to types that you want in Task returns
      /// To support `int` and `unit` for example:
      ///
      /// ```reason
      /// type t('a) =
      ///   | Int: t(int)
      ///   | Unit: t(unit)
      /// ```
      type t('a);

      /// If `'a == 'b` then call `is_equal` on the `'b`, otherwise call `not_equal`
      let if_eq:
        (t('a), t('b), 'b, ~is_equal: 'a => unit, ~not_equal: 'b => unit) =>
        unit;
    },
  ) =>
   {
    module Ident: {
      /// Identifiers that can be serialized and deserialized for the purposes
      /// of RPC/IPC
      type t('a);

      module Encode: {
        type t0('a) = t('a);
        type t;
        let t: t0('a) => t;

        module Set: Set.S with type elt := t;
      };

      module Decode: {let t: (Encode.t, Typ.t('a)) => t('a);};
    };

    module Pending: {
      /// A Task that is waiting for the `ident` to be resolved.
      type t('x, 'a) = {
        ident: Ident.t('a),
        task: Task.t('x, 'a),
      };
    };

    type t;

    let make: unit => t;
    /// Get the next Pending.t
    let nextPending: (t, Typ.t('a), ~loc: string) => Pending.t('x, 'a);
    /// Resolve some Pending.t with a value
    let resolve: (t, Ident.t('a), 'a) => unit;
  };
