import { ProvableExtended } from "./provable";

export { Field, Bool, UInt32, UInt64, Sign };

function Field_(value: bigint | number | string) {
  return {
    value: BigInt(value),

    toBigint() {
      return this.value;
    },
    toConstant() {
      return this;
    },
    toString() {
      return this.value.toString();
    },
    toJSON() {
      return this.toString();
    },
  };
}
type Field = ReturnType<typeof Field_>;

const Field = pseudoClass(
  Field_ as (value: bigint | number | string) => Field,
  { ...ProvableSingleton(Field_) }
);

function Bool_(value: boolean | (0n | 1n)) {
  let field = Field(BigInt(value));
  return {
    ...field,
    value: field.value as 0n | 1n,

    toBigint() {
      return this.value;
    },
    toBoolean() {
      return !this.value;
    },
    toJSON() {
      return this.toBoolean();
    },
  };
}
type Bool = ReturnType<typeof Bool_>;
let BoolProvable = ProvableSingleton<0n | 1n, Bool>(Bool_);
const Bool = pseudoClass(Bool_ as (value: boolean | (0n | 1n)) => Bool, {
  ...BoolProvable,
  toInput(x: Bool) {
    return {
      fields: [],
      packed: [{ field: BoolProvable.toFields(x)[0], bits: 1 }],
    };
  },
  toJSON(x: Bool) {
    return x.toBoolean();
  },
  Unsafe: {
    fromField(x: Field) {
      return Bool(x.value as 0n | 1n);
    },
  },
});

let Bool2: ProvableExtended<Bool> = Bool;

function UInt32_(value: bigint | number | string | Field) {
  let field = typeof value === "object" ? value : Field(value);
  return { ...field };
}
type UInt32 = ReturnType<typeof UInt32_>;
const UInt32 = pseudoClass(
  UInt32_ as (value: bigint | number | string | Field) => UInt32,
  { ...ProvableSingleton(UInt32_) }
);

function UInt64_(value: bigint | number | string | Field) {
  let field = typeof value === "object" ? value : Field(value);
  return { ...field };
}
type UInt64 = ReturnType<typeof UInt64_>;
const UInt64 = pseudoClass(
  UInt64_ as (value: bigint | number | string | Field) => UInt64,
  { ...ProvableSingleton(UInt64_) }
);

function Sign_(value: 1n | -1n) {
  return { ...Field(value), value: value as 1n | -1n };
}
type Sign = ReturnType<typeof Sign_>;
const Sign = pseudoClass(Sign_, {
  ...ProvableSingleton<1n | -1n, Sign>(Sign_),
  toJSON(x: Sign) {
    return x.value === 1n ? "Positive" : "Negative";
  },
});

// helper

function pseudoClass<
  F extends (...args: any) => any,
  M
  // M extends Provable<ReturnType<F>>
>(constructor: F, module: M) {
  return Object.assign<F, M>(constructor, module);
}

function ProvableSingleton<
  TValue extends bigint,
  T extends { value: TValue; toBigint(): bigint }
>(type: (value: TValue) => T): ProvableExtended<T, string> {
  return {
    sizeInFields() {
      return 1;
    },
    toFields(x): Field[] {
      return [Field(x.toBigint())];
    },
    toAuxiliary() {
      return [];
    },
    check() {},
    fromFields([x]) {
      // TODO
      return type(x.value as any);
    },
    toInput(x) {
      return { fields: [Field(x.toBigint())], packed: [] };
    },
    toJSON(x) {
      return x.toBigint().toString();
    },
  };
}
