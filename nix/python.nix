# An overlay defining Python packages
final: prev: {

  cassandra-sigv4 = final.python3Packages.buildPythonPackage rec {
    pname = "cassandra-sigv4";
    version = "4.0.2";
    pyproject = true;
    src = final.python3Packages.fetchPypi {
      inherit pname version;
      hash = "sha256-d/9hI6uUHFCnCuUXed5ae74oQ9lrgMRmrP/fJil0ipg=";
    };
    nativeBuildInputs = with prev.python3Packages; [
      setuptools-scm
      six
      cassandra-driver
      boto3
      mock
    ];
    doCheck = false;
  };

  cqlsh-expansion = final.python3Packages.buildPythonPackage rec {
    pname = "cqlsh-expansion";
    version = "0.9.6";
    pyproject = true;
    src = final.python3Packages.fetchPypi {
      inherit pname version;
      hash = "sha256-ea5ew7aF19JcdzoMgLrvlj0GC/wLfbIsABLKRxcT6DQ=";
    };
    buildInputs = with final.python3Packages; [
      cassandra-driver
      six
      setuptools-scm
      final.cassandra-sigv4
      boto3
    ];
    pythonPath = with final.python3Packages; [
      cassandra-driver
      six
      final.cassandra-sigv4
      boto3
    ];
    permitUserSite = true;
    doCheck = false;
  };
}
