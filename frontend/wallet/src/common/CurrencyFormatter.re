let precision = 9;
let rec pow = a =>
  fun
  | 0 => 1
  | 1 => a
  | n => {
      let b = pow(a, n / 2);
      b
      * b
      * (
        if (n mod 2 == 0) {
          1;
        } else {
          a;
        }
      );
    };
let precision_exp = Int64.of_int(pow(10, precision));
let toFormattedString = amount => {
  let rec go = (num_stripped_zeros, num) =>
    if (num mod 10 == 0 && num != 0) {
      go(num_stripped_zeros + 1, num / 10);
    } else {
      (num_stripped_zeros, num);
    };
  let whole = Int64.div(amount, precision_exp);
  let remainder = Int64.to_int(Int64.rem(amount, precision_exp));
  if (remainder == 0) {
    Int64.to_string(whole);
  } else {
    let (num_stripped_zeros, num) = go(0, remainder);
    Printf.sprintf(
      "%s.%0*d",
      Int64.to_string(whole),
      precision - num_stripped_zeros,
      num,
    );
  };
};
let ofFormattedString = input => {
  let parts = String.split_on_char('.', input);
  switch (parts) {
  | [whole] => Int64.of_string(whole ++ String.make(precision, '0'))
  | [whole, decimal] =>
    let decimal_length = String.length(decimal);
    if (decimal_length > precision) {
      Int64.of_string(whole ++ String.sub(decimal, 0, precision));
    } else {
      Int64.of_string(
        whole ++ decimal ++ String.make(precision - decimal_length, '0'),
      );
    };
  | _ => failwith("Currency.of_formatted_string: Invalid currency input")
  };
};
