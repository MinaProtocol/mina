/* global joo_global_object
 */

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
  // if this didn't throw an error, we try to find a string and throw that
  function throw_strings_as_well(err) {
    if (typeof err === "string") {
      throw joo_global_object.Error(err);
    } else if (err && err.constructor && err.constructor.name === "MlBytes") {
      throw joo_global_object.Error(err.c);
    } else if (Array.isArray(err)) {
      err.forEach(throw_strings_as_well);
    }
  }
  throw_strings_as_well(err);
  // otherwise, just log whatever we got and throw an unhelpful error
  console.dir(err, { depth: 10 });
  throw joo_global_object.Error("Unknown error thrown from OCaml");
}
