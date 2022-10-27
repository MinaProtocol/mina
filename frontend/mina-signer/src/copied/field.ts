import { ProvableExtended } from "./provable";

export { Field, Bool, UInt32, UInt64, Sign };

function Field_(value: bigint | number | string) {
  return {
    value: BigInt(value),

    toConstant() {
      return this;
    },
    toString() {
      return this.value.toString();
    },
    toJSON() {
      return this.toString();
    },
    toField() {
      return Field(this.value);
    },
  };
}
type Field = ReturnType<typeof Field_>;
const FieldProvable: ProvableExtended<Field, string> = {
  sizeInFields() {
    return 1;
  },
  toFields(x): Field[] {
    return [x.toField()];
  },
  toAuxiliary() {
    return [];
  },
  check() {},
  fromFields([x]) {
    return x;
  },
  toInput(x) {
    return { fields: [x], packed: [] };
  },
  toJSON(x) {
    return x.value.toString();
  },
};

const Field = pseudoClass(
  Field_ as (value: bigint | number | string) => Field,
  { ...FieldProvable }
);

function Bool_(value: boolean) {
  let field = Field(BigInt(value));
  return {
    ...field,
    value: field.value as 0n | 1n,

    toBoolean() {
      return !this.value;
    },
    toJSON() {
      return this.toBoolean();
    },
  };
}
type Bool = ReturnType<typeof Bool_>;
const Bool = pseudoClass(Bool_ as (value: boolean | (0n | 1n)) => Bool, {
  ...FieldProvable,
  toInput(x: Bool) {
    return { fields: [], packed: [x, 1] };
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

function UInt32_(value: bigint | number | string | Field) {
  let field = typeof value === "object" ? value : Field(value);
  return { ...field };
}
type UInt32 = ReturnType<typeof UInt32_>;
const UInt32 = pseudoClass(
  UInt32_ as (value: bigint | number | string | Field) => UInt32,
  { ...FieldProvable }
);

function UInt64_(value: bigint | number | string | Field) {
  let field = typeof value === "object" ? value : Field(value);
  return { ...field };
}
type UInt64 = ReturnType<typeof UInt64_>;
const UInt64 = pseudoClass(
  UInt64_ as (value: bigint | number | string | Field) => UInt64,
  { ...FieldProvable }
);

function Sign_(value: Field) {
  return { ...value };
}
type Sign = ReturnType<typeof Sign_>;
const Sign = pseudoClass(Sign_, { ...FieldProvable });

// helper

function pseudoClass<
  F extends (...args: any) => any,
  M
  // M extends Provable<ReturnType<F>>
>(constructor: F, module: M) {
  return Object.assign<F, M>(constructor, module);
}
