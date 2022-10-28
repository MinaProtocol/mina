import { Field } from "./field.js";

export { provable, Provable, ProvableExtended, dataAsHash, HashInput };

/**
 * `Provable<T>` is the general circuit type interface. It describes how a type `T` is made up of field elements and auxiliary (non-field element) data.
 *
 * You will find this as the required input type in a few places in snarkyjs. One convenient way to create a `Provable<T>` is using `Struct`.
 */
declare interface Provable<T> {
  toFields: (x: T) => Field[];
  toAuxiliary: (x?: T) => any[];
  fromFields: (x: Field[], aux: any[]) => T;
  sizeInFields(): number;
  check: (x: T) => void;
}
/**
 * `ProvablePure<T>` is a special kind of `Provable<T>`, where the auxiliary data is empty. This means the type only consists of field elements,
 * in that sense it is "pure".
 *
 * Examples where `ProvablePure<T>` is required are types of on-chain state, events and actions.
 */
declare interface ProvablePure<T> extends Provable<T> {
  toFields: (x: T) => Field[];
  toAuxiliary: (x?: T) => [];
  fromFields: (x: Field[]) => T;
  sizeInFields(): number;
  check: (x: T) => void;
}

type ProvableExtension<T, TJson = JSONValue> = {
  toInput: (x: T) => {
    fields?: Field[];
    packed?: { field: Field; bits: number }[];
  };
  toJSON: (x: T) => TJson;
};
type ProvableExtended<T, TJson = JSONValue> = Provable<T> &
  ProvableExtension<T, TJson>;

let complexTypes = new Set(["object", "function"]);

function provable<A>(
  typeObj: A,
  options?: { customObjectKeys?: string[]; isPure?: boolean }
): ProvableExtended<InferCircuitValue<A>, InferJson<A>> {
  type T = InferCircuitValue<A>;
  type J = InferJson<A>;
  let objectKeys =
    typeof typeObj === "object" && typeObj !== null
      ? options?.customObjectKeys ?? Object.keys(typeObj).sort()
      : [];
  let nonCircuitPrimitives = new Set([
    Number,
    String,
    Boolean,
    BigInt,
    null,
    undefined,
  ]);
  if (
    !nonCircuitPrimitives.has(typeObj as any) &&
    !complexTypes.has(typeof typeObj)
  ) {
    throw Error(`provable: unsupported type "${typeObj}"`);
  }

  function sizeInFields(typeObj: any): number {
    if (nonCircuitPrimitives.has(typeObj)) return 0;
    if (Array.isArray(typeObj))
      return typeObj.map(sizeInFields).reduce((a, b) => a + b, 0);
    if ("sizeInFields" in typeObj) return typeObj.sizeInFields();
    return Object.values(typeObj)
      .map(sizeInFields)
      .reduce((a, b) => a + b, 0);
  }
  function toFields(typeObj: any, obj: any, isToplevel = false): Field[] {
    if (nonCircuitPrimitives.has(typeObj)) return [];
    if (!complexTypes.has(typeof typeObj) || typeObj === null) return [];
    if (Array.isArray(typeObj))
      return typeObj.map((t, i) => toFields(t, obj[i])).flat();
    if ("toFields" in typeObj) return typeObj.toFields(obj);
    return (isToplevel ? objectKeys : Object.keys(typeObj).sort())
      .map((k) => toFields(typeObj[k], obj[k]))
      .flat();
  }
  function toAuxiliary(typeObj: any, obj?: any, isToplevel = false): any[] {
    if (typeObj === Number) return [obj ?? 0];
    if (typeObj === String) return [obj ?? ""];
    if (typeObj === Boolean) return [obj ?? false];
    if (typeObj === BigInt) return [obj ?? 0n];
    if (typeObj === undefined || typeObj === null) return [];
    if (Array.isArray(typeObj))
      return typeObj.map((t, i) => toAuxiliary(t, obj?.[i]));
    if ("toAuxiliary" in typeObj) return typeObj.toAuxiliary(obj);
    return (isToplevel ? objectKeys : Object.keys(typeObj).sort()).map((k) =>
      toAuxiliary(typeObj[k], obj?.[k])
    );
  }
  function toInput(typeObj: any, obj: any, isToplevel = false): HashInput {
    if (nonCircuitPrimitives.has(typeObj)) return {};
    if (Array.isArray(typeObj)) {
      return typeObj
        .map((t, i) => toInput(t, obj[i]))
        .reduce(HashInput.append, {});
    }
    if ("toInput" in typeObj) return typeObj.toInput(obj) as HashInput;
    if ("toFields" in typeObj) {
      return { fields: typeObj.toFields(obj) };
    }
    return (isToplevel ? objectKeys : Object.keys(typeObj).sort())
      .map((k) => toInput(typeObj[k], obj[k]))
      .reduce(HashInput.append, {});
  }
  function toJSON(typeObj: any, obj: any, isToplevel = false): JSONValue {
    if (typeObj === BigInt) return obj.toString();
    if (typeObj === String || typeObj === Number || typeObj === Boolean)
      return obj;
    if (typeObj === undefined || typeObj === null) return null;
    if (!complexTypes.has(typeof typeObj) || typeObj === null)
      return obj ?? null;
    if (Array.isArray(typeObj)) return typeObj.map((t, i) => toJSON(t, obj[i]));
    if ("toJSON" in typeObj) return typeObj.toJSON(obj);
    return Object.fromEntries(
      (isToplevel ? objectKeys : Object.keys(typeObj).sort()).map((k) => [
        k,
        toJSON(typeObj[k], obj[k]),
      ])
    );
  }
  function fromFields(
    typeObj: any,
    fields: Field[],
    aux: any[] = [],
    isToplevel = false
  ): any {
    if (
      typeObj === Number ||
      typeObj === String ||
      typeObj === Boolean ||
      typeObj === BigInt
    )
      return aux[0];
    if (typeObj === undefined || typeObj === null) return typeObj;
    if (!complexTypes.has(typeof typeObj) || typeObj === null) return null;
    if (Array.isArray(typeObj)) {
      let array: any[] = [];
      let i = 0;
      let offset = 0;
      for (let subObj of typeObj) {
        let size = sizeInFields(subObj);
        array.push(
          fromFields(subObj, fields.slice(offset, offset + size), aux[i])
        );
        offset += size;
        i++;
      }
      return array;
    }
    if ("fromFields" in typeObj) return typeObj.fromFields(fields, aux);
    let keys = isToplevel ? objectKeys : Object.keys(typeObj).sort();
    let values = fromFields(
      keys.map((k) => typeObj[k]),
      fields,
      aux
    );
    return Object.fromEntries(keys.map((k, i) => [k, values[i]]));
  }
  function check(typeObj: any, obj: any, isToplevel = false): void {
    if (nonCircuitPrimitives.has(typeObj)) return;
    if (Array.isArray(typeObj))
      return typeObj.forEach((t, i) => check(t, obj[i]));
    if ("check" in typeObj) return typeObj.check(obj);
    return (isToplevel ? objectKeys : Object.keys(typeObj).sort()).forEach(
      (k) => check(typeObj[k], obj[k])
    );
  }
  if (options?.isPure === true) {
    return {
      sizeInFields: () => sizeInFields(typeObj),
      toFields: (obj: T) => toFields(typeObj, obj, true),
      toAuxiliary: () => [],
      toInput: (obj: T) => toInput(typeObj, obj, true),
      toJSON: (obj: T) => toJSON(typeObj, obj, true) as J,
      fromFields: (fields: Field[]) =>
        fromFields(typeObj, fields, [], true) as T,
      check: (obj: T) => check(typeObj, obj, true),
    };
  }
  return {
    sizeInFields: () => sizeInFields(typeObj),
    toFields: (obj: T) => toFields(typeObj, obj, true),
    toAuxiliary: (obj?: T) => toAuxiliary(typeObj, obj, true),
    toInput: (obj: T) => toInput(typeObj, obj, true),
    toJSON: (obj: T) => toJSON(typeObj, obj, true) as J,
    fromFields: (fields: Field[], aux: any[]) =>
      fromFields(typeObj, fields, aux, true) as T,
    check: (obj: T) => check(typeObj, obj, true),
  };
}

// helpers built on provable

function dataAsHash<T, J>({
  emptyValue,
  toJSON,
}: {
  emptyValue: T;
  toJSON: (value: T) => J;
}): ProvableExtended<{ data: T; hash: Field }, J> {
  return {
    sizeInFields() {
      return 1;
    },
    toFields({ hash }) {
      return [hash];
    },
    toAuxiliary(value) {
      return [value?.data ?? emptyValue];
    },
    fromFields([hash], [data]) {
      return { data, hash };
    },
    toJSON({ data }) {
      return toJSON(data);
    },
    check() {},
    toInput({ hash }) {
      return { fields: [hash] };
    },
  };
}

type HashInput = {
  fields?: Field[];
  packed?: { field: Field; bits: number }[];
};
const HashInput = {
  get empty() {
    return {};
  },
  append(input1: HashInput, input2: HashInput): HashInput {
    if (input2.fields !== undefined) {
      (input1.fields ??= []).push(...input2.fields);
    }
    if (input2.packed !== undefined) {
      (input1.packed ??= []).push(...input2.packed);
    }
    return input1;
  },
};

// some type inference helpers

type JSONValue =
  | number
  | string
  | boolean
  | null
  | Array<JSONValue>
  | { [key: string]: JSONValue };

type Constructor<T> = new (...args: any) => T;

type Tuple<T> = [T, ...T[]] | [];

type Primitive =
  | typeof String
  | typeof Number
  | typeof Boolean
  | typeof BigInt
  | null
  | undefined;
type InferPrimitive<P extends Primitive> = P extends typeof String
  ? string
  : P extends typeof Number
  ? number
  : P extends typeof Boolean
  ? boolean
  : P extends typeof BigInt
  ? bigint
  : P extends null
  ? null
  : P extends undefined
  ? undefined
  : any;
type InferPrimitiveJson<P extends Primitive> = P extends typeof String
  ? string
  : P extends typeof Number
  ? number
  : P extends typeof Boolean
  ? boolean
  : P extends typeof BigInt
  ? string
  : P extends null
  ? null
  : P extends undefined
  ? null
  : JSONValue;

type InferCircuitValue<A> = A extends Constructor<infer U>
  ? A extends Provable<U>
    ? U
    : InferCircuitValueBase<A>
  : InferCircuitValueBase<A>;

type InferCircuitValueBase<A> = A extends Provable<infer U>
  ? U
  : A extends Primitive
  ? InferPrimitive<A>
  : A extends Tuple<any>
  ? {
      [I in keyof A]: InferCircuitValue<A[I]>;
    }
  : A extends (infer U)[]
  ? InferCircuitValue<U>[]
  : A extends Record<any, any>
  ? {
      [K in keyof A]: InferCircuitValue<A[K]>;
    }
  : never;

type WithJson<J> = { toJSON: (x: any) => J };

type InferJson<A> = A extends WithJson<infer J>
  ? J
  : A extends Primitive
  ? InferPrimitiveJson<A>
  : A extends Tuple<any>
  ? {
      [I in keyof A]: InferJson<A[I]>;
    }
  : A extends WithJson<infer U>[]
  ? U[]
  : A extends Record<any, any>
  ? {
      [K in keyof A]: InferJson<A[K]>;
    }
  : JSONValue;

type IsPure<A> = IsPureBase<A> extends true ? true : false;

type IsPureBase<A> = A extends ProvablePure<any>
  ? true
  : A extends Provable<any>
  ? false
  : A extends Primitive
  ? false
  : A extends (infer U)[]
  ? IsPure<U>
  : A extends Record<any, any>
  ? {
      [K in keyof A]: IsPure<A[K]>;
    }[keyof A]
  : false;
