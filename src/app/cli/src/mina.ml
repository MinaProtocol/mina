(* !!!CI-FENCE-BEGIN demo: guards a Mina_cli_entrypoint.guarded_hotfix call that is missing; restore it or delete this fence
   #!/usr/bin/env bash
   grep -q '^let () = Mina_cli_entrypoint.guarded_hotfix' src/app/cli/src/mina.ml ||
     { echo "guarded code is gone but the fence is still here"; exit 1; }
   !!!CI-FENCE-END *)
let () = Mina_cli_entrypoint.linkme
