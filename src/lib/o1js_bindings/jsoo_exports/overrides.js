/* global caml_named_value, caml_global_data, caml_string_of_jsstring
 */

//Provides: caml_wrap_exception const (const)
//Requires: caml_global_data,caml_string_of_jsstring,caml_named_value
//Requires: caml_return_exn_constant
function caml_wrap_exception(e) {
  if (e instanceof Array) return e;
  if (e instanceof globalThis.Error && caml_named_value('jsError'))
    return [0, caml_named_value('jsError'), e];
  //fallback: wrapped in Failure
  return [0, caml_global_data.Failure, caml_string_of_jsstring(String(e))];
}

//Provides: caml_raise_with_string (const, const)
function caml_raise_with_string(tag, msg) {
  throw globalThis.Error(msg.c);
}

//Provides: custom_reraise_exn
function custom_reraise_exn(exn, fallbackMessage) {
  // this handles the common case of a JS Error reraised by OCaml
  // in that case, the error will first be wrapped in OCaml with "caml_wrap_exception"
  // (defined in js_of_ocaml-compiler / jslib.js)
  // which results in [0, caml_named_value("jsError"), err]
  var err = exn[2];
  if (err instanceof globalThis.Error) {
    throw err;
  } else {
    throw Error(fallbackMessage);
  }
}

/**
 * This overrides the handler for uncaught exceptions in js_of_ocaml,
 * fixing the flaw that by default, no actual `Error`s are thrown,
 * but other objects (arrays) which are missing an error trace.
 * This override should make it much easier to find the source of an error.
 */
//Provides: caml_fatal_uncaught_exception
function caml_fatal_uncaught_exception(err) {
  // first, we search for an actual error inside `err`,
  // since this is the best thing to throw
  function throw_errors(err) {
    if (err instanceof Error) throw err;
    else if (Array.isArray(err)) {
      err.forEach(throw_errors);
    }
  }
  throw_errors(err);
  // if this didn't throw an error, let's log whatever we got
  console.dir(err, { depth: 20 });
  // now, try to collect all strings in the error and throw that
  function collect_strings(err, acc) {
    var str = undefined;
    if (typeof err === 'string') {
      str = err;
    } else if (err && err.constructor && err.constructor.name === 'MlBytes') {
      str = err.c;
    } else if (Array.isArray(err)) {
      err.forEach(function (e) {
        collect_strings(e, acc);
      });
    }
    if (!str) return acc.string;
    if (acc.string === undefined) acc.string = str;
    else acc.string = acc.string + '\n' + str;
    return acc.string;
  }
  var str = collect_strings(err, {});
  if (str !== undefined) throw globalThis.Error(str);
  // otherwise, just throw an unhelpful error
  console.dir(err, { depth: 10 });
  throw globalThis.Error('Unknown error thrown from OCaml');
}
