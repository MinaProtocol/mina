open Core
open Async

let () = 
  don't_wait_for begin
    let%bind pods = Testbridge.Kubernetes.get_pods () in
    let running_pods = List.filter pods ~f:(fun pod -> pod.status = `Running) in
    let%bind _ = 
      Deferred.List.map running_pods ~f:(fun pod -> 
           Process.run_exn 
             ~prog:"kubectl" 
             ~args:[ "exec"
                   ; pod.Testbridge.Kubernetes.Pod.pod_name
                   ; "cp"; "/app/logs"; "/app/logs-snapshot" ] 
             ())
    in
    let%bind _ = 
      Deferred.List.map running_pods ~f:(fun pod -> 
           Process.run_exn 
             ~prog:"kubectl" 
             ~args:[ "cp"
                   ; pod.Testbridge.Kubernetes.Pod.pod_name ^ ":/app/logs-snapshot"
                   ; "/tmp/testbridge-logs/" ^ pod.Testbridge.Kubernetes.Pod.pod_name ]
             ())
    in
    Async.exit 0
  end
;;

let () = never_returns (Scheduler.go ())
;;
