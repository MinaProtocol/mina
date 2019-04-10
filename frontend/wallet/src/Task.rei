/// A lazy async monad
/// Errors should be captured in a Result type rather than being baked into
/// the monad

include Monad.S;

let create: (('a => unit) => unit) => t('a);

let never: t('a);

let any: array(t('a)) => t('a);

/// Run the task, (only do this at the top of your program or in a test!)
/// Unfortunately since we're in Js land we have an extra layer of crap that can
/// cause us the fail (like bad bindings), hence the result in the callback.
let fork: (t('a), ~f: Result.t('a, Js.Exn.t) => unit) => unit;

module Result: {
  type t0('a, 'err) = t(Result.t('a, 'err));

  include Monad.S2 with type t('a, 'err) = t0('a, 'err);

  /// Take a Node.js style ((nullable err) => unit) => unit function and make it
  /// return a task instead
  let uncallbackify0:
    ((Js.Nullable.t('err) => unit) => unit) => t(unit, 'err);

  /// Take a Node.js style ((nullable err, nullable res) => unit) => unit
  /// function and make it return a task instead
  let uncallbackify:
    (((Js.Nullable.t('err), Js.Nullable.t('a)) => unit) => unit) =>
    t('a, 'err);
};
