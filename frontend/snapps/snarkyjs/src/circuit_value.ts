import 'reflect-metadata';
import { Circuit, Field, Bool, JSONValue } from './snarky';

type Constructor<T> = { new (...args: any[]): T };

export type Tuple<A, _N extends number> = Array<A>;

export abstract class CircuitValue {
  static sizeInFieldElements(): number {
    const fields: [string, any][] = (this as any).prototype._fields;
    return fields.reduce((acc, [_, typ]) => acc + typ.sizeInFieldElements(), 0);
  }

  static toFieldElements<T>(this: Constructor<T>, v: T): Field[] {
    const res: Field[] = [];
    const fields = (this as any).prototype._fields;
    if (fields === undefined || fields === null) {
      return res;
    }

    for (let i = 0; i < fields.length; ++i) {
      const [key, propType] = fields[i];
      const subElts: Field[] = propType.toFieldElements((v as any)[key]);
      subElts.forEach((x) => res.push(x));
    }
    return res;
  }

  toFieldElements(): Field[] {
    return (this.constructor as any).toFieldElements(this);
  }

  toJSON(): JSONValue {
    return (this.constructor as any).toJSON(this);
  }

  equals(this: this, x: typeof this): Bool {
    return Circuit.equal(this, x);
  }

  assertEquals(this: this, x: typeof this): void {
    Circuit.assertEqual(this, x);
  }

  static ofFieldElements<T>(this: Constructor<T>, xs: Field[]): T {
    const fields = (this as any).prototype._fields;
    let offset = 0;
    const props: any[] = [];
    for (let i = 0; i < fields.length; ++i) {
      const propType = fields[i][1];
      const propSize = propType.sizeInFieldElements();
      const propVal = propType.ofFieldElements(
        xs.slice(offset, offset + propSize)
      );
      props.push(propVal);
      offset += propSize;
    }
    return new this(...props);
  }

  static toJSON<T>(this: Constructor<T>, v: T): JSONValue {
    const res: { [key: string]: JSONValue } = {};
    if ((this as any).prototype._fields !== undefined) {
      const fields: [string, any][] = (this as any).prototype._fields;
      fields.forEach(([key, propType]) => {
        res[key] = propType.toJSON((v as any)[key]);
      });
    }
    return res;
  }

  static fromJSON<T>(this: Constructor<T>, value: JSONValue): T | null {
    const props: any[] = [];
    const fields: [string, any][] = (this as any).prototype._fields;

    switch (typeof value) {
      case 'object':
        if (value === null || Array.isArray(value)) {
          return null;
        }
        break;
      default:
        return null;
    }

    if (fields !== undefined) {
      for (let i = 0; i < fields.length; ++i) {
        const [key, propType] = fields[i];
        if (value[key] === undefined) {
          return null;
        } else {
          props.push(propType.fromJSON(value[key]));
        }
      }
    }

    return new this(...props);
  }
}

export function prop(this: any, target: any, key: string) {
  const fieldType = Reflect.getMetadata('design:type', target, key);

  if (target._fields === undefined || target._fields === null) {
    target._fields = [];
  }

  if (fieldType === undefined) {
  } else if (fieldType.toFieldElements && fieldType.ofFieldElements) {
    target._fields.push([key, fieldType]);
  } else {
    console.log(
      `warning: property ${key} missing field element conversion methods`
    );
  }
}

export function public_(target: any, _key: string | symbol, index: number) {
  // const fieldType = Reflect.getMetadata('design:paramtypes', target, key);

  if (target._public === undefined) {
    target._public = [];
  }
  target._public.push(index);
}

type AsFieldElements<A> = {
  sizeInFieldElements: () => number;
  toFieldElements: (x: A) => Array<any>;
  ofFieldElements: (x: Array<any>) => A;
};

function typOfArray(typs: Array<AsFieldElements<any>>): AsFieldElements<any> {
  return {
    sizeInFieldElements: () => {
      return typs.reduce((acc, typ) => acc + typ.sizeInFieldElements(), 0);
    },

    toFieldElements: (t: Array<any>) => {
      if (t.length !== typs.length) {
        throw new Error(`typOfArray: Expected ${typs.length}, got ${t.length}`);
      }

      let res = [];
      for (let i = 0; i < t.length; ++i) {
        res.push(...typs[i].toFieldElements(t[i]));
      }
      return res;
    },

    ofFieldElements: (xs: Array<any>) => {
      let offset = 0;
      let res: Array<any> = [];
      typs.forEach((typ) => {
        const n = typ.sizeInFieldElements();
        res.push(typ.ofFieldElements(xs.slice(offset, offset + n)));
        offset += n;
      });
      return res;
    },
  };
}

export function circuitMain(
  target: any,
  propertyName: string,
  _descriptor?: PropertyDescriptor
): any {
  const paramTypes = Reflect.getMetadata(
    'design:paramtypes',
    target,
    propertyName
  );
  const numArgs = paramTypes.length;

  const publicIndexSet: Set<number> = new Set(target._public);
  const witnessIndexSet: Set<number> = new Set();
  for (let i = 0; i < numArgs; ++i) {
    if (!publicIndexSet.has(i)) {
      witnessIndexSet.add(i);
    }
  }

  target.snarkyMain = (w: Array<any>, pub: Array<any>) => {
    let args = [];
    for (let i = 0; i < numArgs; ++i) {
      args.push((publicIndexSet.has(i) ? pub : w).shift());
    }

    return target[propertyName].apply(target, args);
  };

  target.snarkyWitnessTyp = typOfArray(
    Array.from(witnessIndexSet).map((i) => paramTypes[i])
  );
  target.snarkyPublicTyp = typOfArray(
    Array.from(publicIndexSet).map((i) => paramTypes[i])
  );
}
