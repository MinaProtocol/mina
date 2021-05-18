const snarkette = require('./snarkette_bindings.bc');
const plonkCircuit = require('./plonk_circuit');

const Fields = {
  PastaFp: plonkCircuit.mkField(snarkette.Pasta.fp),
  PastaFq: plonkCircuit.mkField(snarkette.Pasta.fp),
};

const Circuit = plonkCircuit.mkCircuit(Fields.PastaFp);

exports.Fields = Fields;
exports.Field = Fields.PastaFp;
exports.Bool = Fields.PastaFp.Bool;
exports.Circuit = Circuit;
exports.ofFieldElements = function (xs, fields) {
  var start = 0;
  var end;
  var res = [];
  for (var i = 0, l = xs.length; i < l; i++) {
    end = start + xs[i].sizeInFieldElements();
    res.push(xs[i].ofFieldElements(fields.slice(start, end)));
  }
  return res;
}
exports.toFieldElements = function (xs, data) {
  var res = [];
  for (var i = 0, l = xs.length; i < l; i++) {
    res.push(xs[i].toFieldElements(data[i]));
  }
  return res;
}
exports.sizeInFieldElements = function (xs) {
  var sum = 0;
  for (var i = 0, l = xs.length; i < l; i++) {
    sum += xs[i].sizeInFieldElements();
  }
  return sum;
}
exports.NumberAsField = {
  toFieldElements: function () { throw new Error("TODO"); },
  ofFieldElements: function () { throw new Error("TODO"); },
  sizeInFieldElements: function () { throw new Error("TODO"); }
}
exports.array = Circuit.prototype.array;