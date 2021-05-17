let mkField = function(baseField) {
    let toFieldPrimitive = function (x) {
        switch (typeof x) {
            case "number":
                return baseField.ofInt(x);
            case "string":
                return baseField.ofString(x);
            case "boolean":
                if (x) { 
                  return baseField.ofInt(1);
                } else {
                  return baseField.ofInt(0);
                }
            default:
                return x;
        }
    };
    var Field;
    Field = function() {
        if (arguments.length == 1) {
            let x = arguments[0];
            if (x instanceof Field) {
                /* Copy fields */
                this._constant = x._constant;
                this._circuit = x._circuit;
                this._variable = x._variable;
                this._scale = x._scale;
            } else {
                this._constant = toFieldPrimitive(arguments[0]);
            }
        } else if (arguments.length == 2) {
            this._circuit = arguments[0];
            this._variable = arguments[1];
        }
    };
    Field._baseField = baseField;
    let toField = function (x) {
        if (x instanceof Field) {
          return x;
        } else {
          return new Field(x);
        }
    };
    let chooseCircuit = function (x, y) {
        if (x._circuit) {
            if (y._circuit && x._circuit !== y._circuit) {
                throw "Cannot combine variables from different circuits";
            } else {
                return x._circuit;
            }
        } else {
            return y._circuit;
        }
    };
    Field.prototype._value = function() {
        if (this._circuit) {
            return this._circuit._read(this);
        } else {
            return this._constant;
        }
    };
    let negOne = baseField.neg(baseField.one);

    /* Self properties */
    Field.one = new Field(baseField.one);
    Field.zero = new Field(baseField.zero);

    /* Self methods */
    Field.neg = function(x) {
      let x = toField(x);
      if (x._circuit) {
        let res = new Field(x._circuit, x._variable);
        let scale =
          x._scale ? baseField.mul(x._scale, negOne) : negOne;
        let constant =
          x._constant ? baseField.mul(x._constant, negOne) : negOne;
        res._scale = scale;
        res._constant = constant;
        return res;
      } else {
        return new Field(baseField.mul(x._constant, negOne));
      }
    };
    Field.inv = function(x) {
      let x = toField(x);
      if (x._circuit) {
        let res = x._circuit.newVariable(() => {
          return new Field(baseField.inv(x._value()));
        });
        x._circuit.addConstraint("multiply", x, res, Field.one);
        return res;
      } else {
        return new Field(baseField.inv(toField(x)._value()));
      }
    };
    Field.add = function(x, y) {
      let x = toField(x);
      let y = toField(y);
      if (y._circuit && !x._circuit) {
          /* Swap order so that the first argument has the circuit. */
          return Field.add(y, x);
      } else if (x._circuit) {
          if (y._circuit) {
              if (x._circuit !== y._circuit) {
                throw "Cannot add variables from different circuits";
              }
              /* Adding 2 variables. */
              let res = x._circuit.newVariable(() => {
                return new Field(baseField.add(x._value(), y._value()));
              });
              x._circuit.addConstraint("add", x, y, res);
              return res;
          } else {
              /* Adding a constant to a variable. */
              let res = new Field(x._circuit, x._variable);
              res._scale = x._scale;
              res._constant =
                x._constant ? baseField.add(x._constant, y._value())
                            : y._value();
              return res;
          }
      } else {
          return new Field(baseField.add(x._value(), y._value()));
      }
    };
    Field.sub = function(x, y) {
      let x = toField(x);
      let y = toField(y);
      return Field.add(x, Field.neg(y));
    };
    Field.mul = function(x, y) {
      let x = toField(x);
      let y = toField(y);
      if (y._circuit && !x._circuit) {
          /* Swap order so that the first argument has the circuit. */
          return Field.mul(y, x);
      } else if (x._circuit) {
          if (y._circuit) {
              if (x._circuit !== y._circuit) {
                throw "Cannot multiply variables from different circuits";
              }
              /* Adding 2 variables. */
              let res = x._circuit.newVariable(() => {
                return new Field(baseField.mul(x._value(), y._value()));
              });
              x._circuit.addConstraint("multiply", x, y, res);
              return res;
          } else {
              /* Scaling a variable by a constant. */
              let res = new Field(x._circuit, x._variable);
              res._scale =
                x._scale ? baseField.mul(x._scale, y._value())
                         : y._value();
              ;
              res._constant =
                x._constant ? baseField.mul(x._constant, y._value())
                              : undefined;
              return res;
          }
      } else {
          return new Field(baseField.mul(x._value(), y._value()));
      }
    };
    Field.div = function(x, y) {
      let x = toField(x);
      let y = toField(y);
      if (x._circuit && y._circuit) {
         if (x._circuit !== y._circuit) {
           throw "Cannot multiply variables from different circuits";
         }
         /* Adding 2 variables. */
         let res = x._circuit.newVariable(() => {
           return new Field(baseField.div(x._value(), y._value()));
         });
         x._circuit.addConstraint("multiply", res, y, x);
         return res;
      } else {
          return Field.mul(x, Field.inv(y));
      }
    };
    Field.square = function(x) {
      let x = toField(x);
      return Field.mul(x, x);
    };
    Field.sqrt = function(x) {
      let x = toField(x);
      if (x._circuit) {
        let res = x._circuit.newVariable(() => {
          return new Field(baseField.sqrt(x._value()));
        });
        x._circuit.addContraint("multiply", res, res, x);
      }
    };
    Field.toString = function(x) {
      if (x._circuit) {
        return "[CircuitVariable]"
      } else {
        return (baseField.toString(x._value()));
      }
    }

    /* Prototype methods */
    Field.prototype.neg = function() { return Field.neg(this); };
    Field.prototype.inv = function() { return Field.inv(this); };
    Field.prototype.add = function(y) { return Field.add(this, y); };
    Field.prototype.sub = function(y) { return Field.sub(this, y); };
    Field.prototype.mul = function(y) { return Field.mul(this, y); };
    Field.prototype.div = function(y) { return Field.div(this, y); };
    Field.prototype.square = function() { return Field.square(this); };
    Field.prototype.sqrt = function() { return Field.sqrt(this); };
    Field.prototype.value = function() { return new Field(this._value()); };
    Field.prototype.toString = function() { return Field.toString(this); };
    return Field;
};

let mkCircuit = function(Field) {
    let Circuit = function() {
        this._nextVariable = 0;
        this._nextPublicVariable = 0; /* Uses negative indices. */
        this._variables = [];
        this._publicVariables = [];
        this._constraints = [];
        this._isProver = false;
    };
    Circuit.prototype.addConstraint = function (kind) {
        /* Generic gate is ql * l + qr * r + qo * o + qm * l * r + qc = 0 */
        switch (kind) {
            case "multiply":
                /* (qx * x + cx) * (qy * y + cy) = (qz * z + cz)
                   qx * qy * (x * y) + (qx * cy) * x + (qy * cx) * y + cx * cy = qz * z + cz
                */
                let x = arguments[1];
                let y = arguments[2];
                let z = arguments[3];
                var qx = new Field(x._scale ? x._scale : 1);
                var cx = new Field(x._constant ? x._constant : 0);
                var qy = new Field(y._scale ? y._scale : 1);
                var cy = new Field(y._constant ? y._constant : 0);
                var qz = new Field(z._scale ? z._scale : 1);
                var cz = new Field(z._constant ? z._constant : 0);
                if (!x._variable) {
                  qx = Field.zero;
                }
                if (!y._variable) {
                  qy = Field.zero;
                }
                if (!z._variable) {
                  qz = Field.zero;
                }
                let ql = qx.mul(cy);
                let qr = qy.mul(cx);
                let qo = qz.neg();
                let qm = qx.mul(qy);
                let qc = cx.mul(cy).sub(cz);
                let l = x._variable ? x._variable : 0;
                let r = y._variable ? y._variable : 0;
                let o = z._variable ? z._variable : 0;

                this._constraints.push({
                  kind: "generic", 
                  ql: ql.toString(),
                  qr: qr.toString(),
                  qo: qo.toString(),
                  qm: qm.toString(),
                  qc: qc.toString(),
                  l: l,
                  r: r,
                  o: o
                });
                break;
            case "add":
                /* (qx * x + cx) + (qy * y + cy) = (qz * z + cz)
                   qx * x + qy * y + (cx + cy) = qz * z + cz
                */
                let x = arguments[1];
                let y = arguments[2];
                let z = arguments[3];
                var qx = new Field(x._scale ? x._scale : 1);
                var cx = new Field(x._constant ? x._constant : 0);
                var qy = new Field(y._scale ? y._scale : 1);
                var cy = new Field(y._constant ? y._constant : 0);
                var qz = new Field(z._scale ? z._scale : 1);
                var cz = new Field(z._constant ? z._constant : 0);
                if (!x._variable) {
                  qx = Field.zero;
                }
                if (!y._variable) {
                  qy = Field.zero;
                }
                if (!z._variable) {
                  qz = Field.zero;
                }
                let ql = qx;
                let qr = qy;
                let qo = qz;
                let qm = Field.zero;
                let qc = cx.add(cy).sub(cz);
                let l = x._variable ? x._variable : 0;
                let r = y._variable ? y._variable : 0;
                let o = z._variable ? z._variable : 0;

                this._constraints.push({
                  kind: "generic", 
                  ql: ql.toString(),
                  qr: qr.toString(),
                  qo: qo.toString(),
                  qm: qm.toString(),
                  qc: qc.toString(),
                  l: l,
                  r: r,
                  o: o
                });
                break;
            case "equal":
                /* qx * x + cx = qy * y + cy */
                let x = arguments[1];
                let y = arguments[2];
                var qx = new Field(x._scale ? x._scale : 1);
                var cx = new Field(x._constant ? x._constant : 0);
                var qy = new Field(y._scale ? y._scale : 1);
                var cy = new Field(y._constant ? y._constant : 0);
                if (!x._variable) {
                  qx = Field.zero;
                }
                if (!y._variable) {
                  qy = Field.zero;
                }
                let ql = qx;
                let qr = qy;
                let qo = Field.zero;
                let qm = Field.zero;
                let qc = cx.sub(cy);
                let l = x._variable ? x._variable : 0;
                let r = y._variable ? y._variable : 0;
                let o = 0;

                this._constraints.push({
                  kind: "generic", 
                  ql: ql.toString(),
                  qr: qr.toString(),
                  qo: qo.toString(),
                  qm: qm.toString(),
                  qc: qc.toString(),
                  l: l,
                  r: r,
                  o: o
                });
                break;
            case "boolean":
                /* (qx * x + cx) * (qx * x + cx) = (qx * x + cx)
                   qx * qx * (x * x) + qx * cx * x + qx * cx * x + cx * cx = qx * x + cx
                   qx * qx * (x * x) + (2 * qx * cx - qx) * x + (cx * cx - cx) = 0
                */
                let x = arguments[1];
                var qx = new Field(x._scale ? x._scale : 1);
                var cx = new Field(x._constant ? x._constant : 0);
                if (!x._variable) {
                  qx = Field.zero;
                }
                let ql = qx.mul(2).mul(cx);
                let qr = Field.zero;
                let qo = Field.zero;
                let qm = qx.mul(qx);
                let qc = cx.mul(cx).sub(cx);
                let l = x._variable ? x._variable : 0;
                let r = x._variable ? x._variable : 0;
                let o = 0;

                this._constraints.push({
                  kind: "generic", 
                  ql: ql.toString(),
                  qr: qr.toString(),
                  qo: qo.toString(),
                  qm: qm.toString(),
                  qc: qc.toString(),
                  l: l,
                  r: r,
                  o: o
                });
                break;
        }
    };
    Circuit.prototype.newVariable = function (arg) {
        if (this._isProver) {
            if (arg) {
                var value;
                if (typeof arg === "function") {
                    value = new Field(arg.call(this));
                } else if (arg instanceof Field) {
                    value = arg;
                } else {
                    value = new Field(arg);
                }
                value = value.value();
                return new Field(value);
            } else {
                throw "Cannot allocate new unfilled variables in prover-only code";
            }
        } else {
            /* Pre-increment to allow space for the constant at variable 0. */
            let variable = ++this._nextVariable;
            if (arg) {
                var value;
                this._isProver = true;
                if (typeof arg === "function") {
                    value = new Field(arg.call(this));
                } else if (arg instanceof Field) {
                    value = arg;
                } else {
                    value = new Field(arg);
                }
                value = value.value();
                this._isProver = false;
                this._variables[variable] = value;
            }
            return new Field(this, variable);
        } else if (this._isProver) {
            throw "Cannot allocate new unfilled variables in prover-only code"
        } else {
            let variable = ++this._nextVariable;
            return new Field(this, variable);
        }
    };
    Circuit.prototype.newPublicVariable = function (arg) {
        if (this._isProver) {
            throw "Cannot allocate new public variables in prover-only code";
        } else {
            /* Public variables are given negative indices, so that we can add
               arbitrarily without disrupting the numbers of normal variables.
            */
            let variable = -(this._nextPublicVariable++);
            if (arg) {
                var value;
                this._isProver = true;
                if (typeof arg === "function") {
                    value = new Field(arg.call(this));
                } else if (arg instanceof Field) {
                    value = arg;
                } else {
                    value = new Field(arg);
                }
                value = value.value();
                this._isProver = false;
                this._variables[variable] = value;
            }
            return new Field(this, variable);
        } else if (this._isProver) {
            throw "Cannot allocate new unfilled variables in prover-only code"
        } else {
            let variable = ++this._nextVariable;
            return new Field(this, variable);
        }
    };
    return Circuit;
};

exports.mkField = mkField;
exports.mkCircuit = mkCircuit;
