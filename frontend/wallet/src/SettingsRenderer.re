let lookup = Settings.lookup;

let add = (_t, ~key, ~name) => {
  MainCommunication.setName(key, name);
};
