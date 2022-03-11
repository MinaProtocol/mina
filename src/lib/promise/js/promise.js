// Provides: deferred_run
function deferred_run(func) {
  var deferred = {
    promise: Promise.resolve()
      .then(func) // the ocaml types don't know this, but func can actually be async or sync
      .then(function (value) {
        deferred.value = value;
        deferred.isDetermined = true;
        return value;
      })
      .catch(function (err) {
        deferred.error = err;
        deferred.isDetermined = true;
        throw err;
      }),
    isDetermined: false,
  };
  return deferred;
}

// Provides: deferred_map
function deferred_map(deferred, func) {
  var newDeferred = {
    promise: deferred.promise
      .then(func) // the ocaml types don't know this, but func can actually be async or sync
      .then(function (value) {
        newDeferred.value = value;
        newDeferred.isDetermined = true;
        return value;
      })
      .catch(function (err) {
        newDeferred.error = err;
        newDeferred.isDetermined = true;
        throw err;
      }),
    isDetermined: false,
  };
  return newDeferred;
}

// Provides: deferred_bind
function deferred_bind(deferred, func) {
  var newDeferred = {
    promise: deferred.promise
      .then(func)
      .then(function (anotherDeferred) {
        return anotherDeferred.promise;
      })
      .then(function (value) {
        newDeferred.value = value;
        newDeferred.isDetermined = true;
        return value;
      })
      .catch(function (err) {
        newDeferred.error = err;
        newDeferred.isDetermined = true;
        throw err;
      }),
    isDetermined: false,
  };
  return newDeferred;
}

// Provides: deferred_upon
function deferred_upon(deferred, func) {
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
  if (deferred.isDetermined) {
    return [1, deferred.value];
  } else {
    return [0];
  }
}

// Provides: deferred_value_exn
function deferred_value_exn(deferred) {
  if (!deferred.isDetermined) {
    throw Error("Deferred has not returned yet.");
  }
  if (deferred.error) {
    throw deferred.error;
  }
  return deferred.value;
}

// Provides: deferred_return
function deferred_return(value) {
  return {
    promise: Promise.resolve(value),
    value: value,
    isDetermined: true,
  };
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
        deferred.isDetermined = true;
        throw err;
      }),
    isDetermined: false,
  };
  return deferred;
}
