open Core

let validate_filename name =
  (if String.contains name '/'
   then failwithf "File or directory name cannot contain a slash. Got %s" name ())
;;
