// Actions for the application

type t('window, 'proc) =
  | PutWindow(option('window))
  // stop by sending None
  // start by sending Some(args)
  | ControlCoda(option(list(string)))
  // Coda crashed with this message
  | CodaCrashed([ | `Code(int) | `Signal(string)])
  // if we're starting coda asynchronously after waiting
  | CodaStarted(list(string), 'proc);
