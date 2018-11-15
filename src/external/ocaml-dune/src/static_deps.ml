open! Import

type t =
  { rule_deps   : Deps.t
  ; action_deps : Deps.t
  }

let action_deps t = t.action_deps

let rule_deps t = t.rule_deps

let empty =
  { rule_deps = Deps.empty
  ; action_deps = Deps.empty
  }

let add_rule_paths t fns =
  { t with
    rule_deps = Deps.add_paths t.rule_deps fns
  }

let add_rule_path t fn =
  { t with
    rule_deps = Deps.add_path t.rule_deps fn
  }

let add_action_paths t fns =
  { t with
    action_deps = Deps.add_paths t.action_deps fns
  }

let add_action_env_var t var =
  { t with
    action_deps = Deps.add_env_var t.action_deps var
  }

let paths {action_deps; rule_deps} =
  Deps.path_union action_deps rule_deps
