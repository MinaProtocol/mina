import { Field as F, Circuit as C } from './bindings/snarky2';
import { Snapp as S } from './mina';



export type Field = F;
export type Circuit = C;
export type Snapp = S;

import { main } from './examples/exchange';

export const exchange = main;
exchange();


// for testing tests
export const five: number = 5;
