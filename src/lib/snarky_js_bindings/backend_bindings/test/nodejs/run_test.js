var tests = require("./nodejs_test.bc.js");
var trace = "";
var old_log = console.log;
// Accumulate the logs, only print them when we fail.
console.log = function(string) {
    trace += string + "\n";
}
tests.snarky_ready.then(function () {
    console.log("bigint_256_test");
    tests.bigint_256_test.run();
    console.log("pasta_fp_test");
    tests.pasta_fp_test.run();
    console.log("pasta_fq_test");
    tests.pasta_fq_test.run();
    console.log("pasta_fp_vector_test");
    tests.pasta_fp_vector_test.run();
    console.log("pasta_fq_vector_test");
    tests.pasta_fq_vector_test.run();
    console.log("pasta_pallas_test");
    tests.pasta_pallas_test.run();
    console.log("pasta_vesta_test");
    tests.pasta_vesta_test.run();
    console.log("pasta_fp_gate_vector_test");
    tests.pasta_fp_gate_vector_test.run();
    console.log("pasta_fq_gate_vector_test");
    tests.pasta_fq_gate_vector_test.run();
    console.log("pasta_fp_index_test");
    tests.pasta_fp_index_test.run();
    console.log("pasta_fq_index_test");
    tests.pasta_fq_index_test.run();
    console.log("pasta_fp_verifier_index_test");
    tests.pasta_fp_verifier_index_test.run();
    console.log("pasta_fq_verifier_index_test");
    tests.pasta_fq_verifier_index_test.run();
    console.log("snarky_test");
    tests.snarky_test.run();
}).then(
    function() { process.exit(0); },
    function(err) {
        old_log(trace);
        old_log(err);
        process.exit(1);
    } );
