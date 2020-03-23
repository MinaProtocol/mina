// let precision = 9;
// let rec pow = a =>
//   fun
//   | 0 => 1
//   | 1 => a
//   | n => {
//       let b = pow(a, n / 2);
//       b
//       * b
//       * (
//         if (n mod 2 == 0) {
//           1;
//         } else {
//           a;
//         }
//       );
//     };
// let precision_exp = Int64.of_int(pow(10, precision));
// let to_formatted_string = amount => {
//   let rec go = (num_stripped_zeros, num) =>
//     Int64.(
//       if (num mod 10 == 0 && num != 0) {
//         go(num_stripped_zeros + 1, num / 10);
//       } else {
//         (num_stripped_zeros, num);
//       }
//     );
//   let whole = Int64.div(amount, precision_exp);
//   let remainder = Int64.to_int(Int64.rem(amount, precision_exp));
//   if (Int64.(remainder == 0)) {
//     Int64.to_string(whole);
//   } else {
//     let (num_stripped_zeros, num) = go(0, remainder);
//     Printf.sprintf(
//       "%s.%0*d",
//       Int64.to_string(whole),
//       Int64.(precision - num_stripped_zeros),
//       num,
//     );
//   };
// };
// let of_formatted_string = input => {
//   let parts = String.split_on_char('.', input);
//   switch (parts) {
//   | [whole] => of_string(whole ++ String.make(precision, '0'))
//   | [whole, decimal] =>
//     let decimal_length = String.length(decimal);
//     if (Int.(decimal_length > precision)) {
//       of_string(whole ++ String.sub(decimal, ~pos=0, ~len=precision));
//     } else {
//       of_string(
//         whole ++ decimal ++ String.make(Int.(precision - decimal_length), '0'),
//       );
//     };
//   | _ => failwith("Currency.of_formatted_string: Invalid currency input")
//   };
// };
