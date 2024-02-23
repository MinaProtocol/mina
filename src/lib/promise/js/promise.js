// Provides: deferred_run
function deferred_run(func) {
  if (func.length > 1) {
    // we add this restriction to be able to use .then(func) below,
    // which allows us to implement external functions that are synchronous
    // in native Rust with async functions in JS
    throw Error(
      'deferred_run cannot be called with a function that takes more than 1 argument.'
    );
  }
  var deferred = {
    promise: globalThis.Promise.resolve()
      .then(func) // the ocaml types don't know this, but func can actually be async or sync
      .then(function (value) {
        deferred.value = value;
        deferred.isDetermined = true;
        return value;
      })
      .catch(function (err) {
        deferred.error = err;
        deferred.isError = true;
        deferred.isDetermined = true;
        throw err;
      }),
    isError: false,
    isDetermined: false,
  };
  return deferred;
}

// Provides: deferred_map
// Requires: deferred_of_promise
function deferred_map(deferred, func) {
  return deferred_of_promise(
    deferred.promise.then(function (value) {
      // we might be given a `func` with multiple arguments,
      // have to match ocaml call semantics
      if (func.length === 1) return func(value);
      return function () {
        return func.apply(null, [value].concat(Array.from(arguments)));
      };
    })
  );
}

// Provides: deferred_bind
function deferred_bind(deferred, func) {
  var newDeferred = {
    promise: deferred.promise
      .then(function (input) {
        var anotherDeferred = func(input);
        return anotherDeferred.promise;
      })
      .then(function (value) {
        newDeferred.value = value;
        newDeferred.isDetermined = true;
        return value;
      })
      .catch(function (err) {
        newDeferred.error = err;
        newDeferred.isError = true;
        newDeferred.isDetermined = true;
        throw err;
      }),
    isError: false,
    isDetermined: false,
  };
  return newDeferred;
}

// Provides: deferred_upon
function deferred_upon(deferred, func) {
  deferred.promise
    .then(function () {
      func(deferred.value);
    })
    .catch(function () {});
}

// Provides: deferred_upon_exn
function deferred_upon_exn(deferred, func) {
  deferred.promise.then(function () {
    func(deferred.value);
  });
}

// Provides: deferred_is_determined
function deferred_is_determined(deferred) {
  return deferred.isDetermined;
}

// Provides: deferred_peek
function deferred_peek(deferred) {
  if (!deferred.isDetermined || deferred.isError) {
    return 0;
  }
  return [0, deferred.value];
}

// Provides: deferred_value_exn
function deferred_value_exn(deferred) {
  if (!deferred.isDetermined) {
    throw Error('Deferred has not returned yet.');
  }
  if (deferred.isError) {
    throw deferred.error;
  }
  return deferred.value;
}

// Provides: deferred_return
function deferred_return(value) {
  return {
    promise: globalThis.Promise.resolve(value),
    value: value,
    isError: false,
    isDetermined: true,
  };
}

// Provides: deferred_create
function deferred_create(promise_creator) {
  var deferred = {
    promise: new globalThis.Promise(function (resolve) {
      promise_creator(resolve);
    })
      .then(function (value) {
        deferred.value = value;
        deferred.isDetermined = true;
      })
      .catch(function (err) {
        deferred.error = err;
        deferred.isError = true;
        deferred.isDetermined = true;
        throw err;
      }),
    isError: false,
    isDetermined: false,
  };
  return deferred;
}

// Provides: deferred_to_promise
function deferred_to_promise(deferred) {
  return deferred.promise;
}

// Provides: deferred_of_promise
function deferred_of_promise(promise) {
  var deferred = {
    promise: promise
      .then(function (value) {
        deferred.value = value;
        deferred.isDetermined = true;
        return value;
      })
      .catch(function (err) {
        deferred.error = err;
        deferred.isError = true;
        deferred.isDetermined = true;
        throw err;
      }),
    isError: false,
    isDetermined: false,
  };
  return deferred;
}
