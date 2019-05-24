// Actions for the application

type t('window) =
  | PutWindow(option('window))
  // stop by sending None
  // start by sending Some(args)
  | ControlCoda(option(list(string)))
  // Coda crashed with this message
  | CodaCrashed([ | `Code(int) | `Signal(string)]);
