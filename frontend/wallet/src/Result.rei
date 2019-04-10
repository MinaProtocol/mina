/// A result type, just in case we want to move between Belt, Base, or
/// Tablecloth etc

type t_('a, 'b) =
  | Ok('a)
  | Error('b);

include Monad.S2 with type t('a, 'b) = t_('a, 'b);

let fail: 'b => t('a, 'b);

let ok: t('a, 'b) => option('a);

let ok_exn: t('a, Js.Exn.t) => 'a;

let err: t('a, 'b) => option('b);

let map_error: (t('a, 'b), ~f: 'b => 'c) => t('a, 'c);
