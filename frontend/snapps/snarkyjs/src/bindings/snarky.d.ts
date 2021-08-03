export type AsField<F> = F | number | string | boolean;

export class Keypair {
}

export class Proof {
}

export class Field {
  constructor(x: AsField<Field>);

  neg(this: Field): Field;
  inv(this: Field): Field;

  add(this: Field, y: AsField<Field>): Field;
  sub(this: Field, y: AsField<Field>): Field;
  mul(this: Field, y: AsField<Field>): Field;
  div(this: Field, y: AsField<Field>): Field;

  square(this: AsField<Field>): Field;
  sqrt(this: AsField<Field>): Field;

  toString(this: AsField<Field>): string;

  sizeInFieldElements(): number;
  toFieldElements(this: AsField<Field>): Field[];

  assertEquals(this: AsField<Field>, y: AsField<Field>): void;
  assertBoolean(this: AsField<Field>): void;
  isZero(this: AsField<Field>): Bool;

  toBits(this: AsField<Field>): Bool[];

  equals(this: AsField<Field>, y: AsField<Field>): Bool;

  // value(this: AsField<Field>): Field;

  /* Self members */
  static one: Field;
  static zero: Field;
  static random(): Field;

  static neg(x: AsField<Field>): Field;
  static inv(x: AsField<Field>): Field;

  static add(x: AsField<Field>, y: AsField<Field>): Field;
  static sub(x: AsField<Field>, y: AsField<Field>): Field;
  static mul(x: AsField<Field>, y: AsField<Field>): Field;
  static div(x: AsField<Field>, y: AsField<Field>): Field;

  static square(x: AsField<Field>): Field;
  static sqrt(x: AsField<Field>): Field;

  static toString(x: AsField<Field>): string;

  static sizeInFieldElements(): number;
  static toFieldElements(x: AsField<Field>): Field[];
  static ofFieldElements(fields: Field[]): Field;

  static assertEqual(x: AsField<Field>, y: AsField<Field>): Field;
  static assertBoolean(x: AsField<Field>): void;
  static isZero(x: AsField<Field>): Bool;

  static ofBits(x: AsBool<Bool>[]): Field;
  static toBits(x: AsField<Field>): Bool[];

  static equal(x: AsField<Field>, y: AsField<Field>): Bool;
}

export type AsBool<B> = B | boolean;

export class Bool {
  constructor(x: AsBool<Bool>);

  toField(this: AsBool<Bool>): Field;

  not(this: Bool): Bool;
  and(this: Bool, y: AsBool<Bool>): Bool;
  or(this: Bool, y: AsBool<Bool>): Bool;

  assertEquals(this: Bool, y: AsBool<Bool>): void;

  equals(this: Bool, y: AsBool<Bool>): Bool;
  isTrue(this: Bool): Bool;
  isFalse(this: Bool): Bool;

  sizeInFieldElements(): number;
  toFieldElements(this: Bool): Field[];

  toString(this: Bool): string;

  /* static members */
  static toField(x: AsBool<Bool>): Field;

  static Unsafe: {
    ofField(x: AsField<Field>): Bool;
  };

  static not(x: AsBool<Bool>): Bool;
  static and(x: AsBool<Bool>, y: AsBool<Bool>): Bool;
  static or(x: AsBool<Bool>, y: AsBool<Bool>): Bool;

  static assertEqual(x: AsBool<Bool>, y: AsBool<Bool>): void;

  static equal(x: AsBool<Bool>, y: AsBool<Bool>): Bool;
  static isTrue(x: AsBool<Bool>): Bool;
  static isFalse(x: AsBool<Bool>): Bool;

  static count(x: AsBool<Bool>[]): Field;

  static sizeInFieldElements(): number;
  static toFieldElements(x: AsBool<Bool>): Field[];
  static ofFieldElements(fields: Field[]): Bool;
}

export interface AsFieldElements<T> {
  toFieldElements(x: T): Field[];
  ofFieldElements(x: Field[]): T;
  sizeInFieldElements(): number;
}

export interface CircuitMain<W, P> {
  snarkyWitnessTyp: AsFieldElements<W>,
  snarkyPublicTyp: AsFieldElements<P>,
  snarkyMain: (W, P) => void
}

export class Circuit {
  static addConstraint(
    this: Circuit,
    kind: 'multiply',
    x: Field,
    y: Field,
    z: Field
  ): void;
  static addConstraint(this: Circuit, kind: 'add', x: Field, y: Field, z: Field): void;
  static addConstraint(
    this: Circuit,
    kind: 'equal',
    x: Field,
    y: Field,
    z: Field
  ): void;
  static addConstraint(
    this: Circuit,
    kind: 'boolean',
    x: Field,
    y: Field,
    z: Field
  ): void;

  // newVariable(): Field;
  // newVariable(x: AsField<Field>): Field;
  // TODO
  static newVariable(f: () => AsField<Field>): Field;

  /*
  newPublicVariable(): Field;
  newPublicVariable(x: AsField<Field>): Field;
  newPublicVariable(f: () => AsField<Field>): Field;

  setVariable(x: Field, value: AsField<Field>): void;
  setVariable(x: Field, f: () => AsField<Field>): void;
  */

  static witness<T>(
    ctor: { toFieldElements(x: T): Field[]; ofFieldElements(x: Field[]): T; sizeInFieldElements(): number },
    f: () => T
  ): T;

  static array<T>(
    ctor: AsFieldElements<T>,
    length: number
  ): AsFieldElements<T[]>;

  static assertEqual<T>(
    ctor: { toFieldElements(x: T): Field[] },
    x: T,
    y: T
  ): void;

  static assertEqual(
    x: T,
    y: T
  ): void;

  static equal<T>(
    ctor: { toFieldElements(x: T): Field[] },
    x: T,
    y: T
  ): Bool;

  static equal(
    x: T,
    y: T
  ): Bool;

  static if<T>(
    b: AsBool<Bool>,
    ctor: AsFieldElements<T>,
    x: T,
    y: T
  ): T;

  static if(
    b: AsBool<Bool>,
    x: T,
    y: T
  ): T;

  static generateKeypair<W, P>(
    main: CircuitMain<W, P>,
  ): Keypair;

  static prove<W, P>(
    main: CircuitMain<W, P>,
    w: W, p: P,
    kp: Keypair
  ): Proof;
}

export class Scalar {
    toFieldElements(this: Scalar): Field[];

    static toFieldElements(x: Scalar): Field[]
    static ofFieldElements(fields: Field[]): Scalar;
    static sizeInFieldElements(): number;
    static ofBits(bits: Bool[]): Scalar;
}

export class EndoScalar {
    static toFieldElements(x: Scalar): Field[]
    static ofFieldElements(fields: Field[]): Scalar;
    static sizeInFieldElements(): number;
}

export class Group {
    x: Field;
    y: Field;

    add(this: Group, y: Group): Group;
    sub(this: Group, y: Group): Group;
    neg(this: Group): Group;
    scale(this: Group, y: Scalar): Group;
    endoScale(this: Group, y: EndoScalar): Group;

    assertEquals(this: Group, y: Group): void;
    equals(this: Group, y: Group): Bool;

    constructor(args: { x: AsField<Field>, y: AsField<Field> })
    constructor(x: AsField<Field>, y: AsField<Field>)

    static generator: Group;
    static add(x: Group, y: Group): Group;
    static sub(x: Group, y: Group): Group;
    static neg(x: Group): Group;
    static scale(x: Group, y: Scalar): Group;
    static endoScale(x: Group, y: EndoScalar): Group;

    static assertEqual(x: Group, y: Group): void;
    static equal(x: Group, y: Group): Bool;

    static toFieldElements(x: Group): Field[]
    static ofFieldElements(fields: Field[]): Group;
    static sizeInFieldElements(): number;
}

export const Poseidon : {
  hash: (xs: Field[]) => Field;
};

/* TODO: Figure out types for these. */
export const ofFieldElements: (x: any[], y: any[]) => any[];
export const toFieldElements: (x: any[], y: any[]) => any[];
export const sizeInFieldElements: (x: any[]) => number;

export const NumberAsField: AsFieldElements<Number>;

export const array: <T>(x: AsFieldElements<T>, length: number) => AsFieldElements<T[]>;
