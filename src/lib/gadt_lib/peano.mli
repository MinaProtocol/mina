type zero = unit

type 'n succ = zero -> 'n

type _0 = zero

type _1 = zero succ

type _2 = _1 succ

type _3 = _2 succ

type _4 = _3 succ

type _5 = _4 succ

type _6 = _5 succ

type 'n gt_0 = 'n succ

type 'n gt_1 = 'n succ succ

type 'n gt_2 = 'n succ gt_1

type 'n gt_3 = 'n succ gt_2

type 'n gt_4 = 'n succ gt_3

type 'n gt_5 = 'n succ gt_4

type 'n gt_6 = 'n succ gt_5

type 'n t = Z : zero t | S : 'n t -> 'n succ t

val _0 : zero t

val _1 : zero succ t

val _2 : zero succ succ t

val _3 : zero succ succ succ t

val _4 : zero succ succ succ succ t

val _5 : zero succ succ succ succ succ t

val _6 : zero succ succ succ succ succ succ t
