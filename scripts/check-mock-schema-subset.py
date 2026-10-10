#!/usr/bin/env python3
"""
Verify that mock_schema.json is a structural SUBSET of graphql_schema.json.

Subset semantics:
- Every named type in mock must also exist in real, with the same `kind`.
- For each type, every field in mock must exist in real with matching
  return type and matching argument list.
- For input objects, every input field in mock must exist in real with
  matching type.
- Real schema is allowed to have additional types/fields not in mock.

Exit codes:
  0  Mock is a subset of real.
  1  Mock declares types/fields the real schema does not have, or shapes diverge.
  2  Argument/usage error.

Designed for CI; output is plain text with a summary at the bottom.
"""

import json
import sys


def types_to_dict(introspection):
    """Map every named type in the introspection result by its name."""
    schema = introspection.get("data", {}).get("__schema", {})
    return {t["name"]: t for t in schema.get("types", []) if t.get("name")}


def fields_by_name(type_obj, key):
    """Index a type's `fields` or `inputFields` list by field name."""
    items = type_obj.get(key) or []
    return {f["name"]: f for f in items}


def normalize_type_ref(ref):
    """Reduce a graphql-introspection type ref to a hashable form for diff."""
    if ref is None:
        return None
    return (ref.get("kind"), ref.get("name"), normalize_type_ref(ref.get("ofType")))


def normalize_arg(arg):
    return (arg["name"], normalize_type_ref(arg.get("type")))


def normalize_args(args):
    return sorted(normalize_arg(a) for a in (args or []))


def check_subset(mock_path, real_path):
    with open(mock_path) as f:
        mock = json.load(f)
    with open(real_path) as f:
        real = json.load(f)

    mock_types = types_to_dict(mock)
    real_types = types_to_dict(real)

    errors = []

    for name, mock_t in mock_types.items():
        real_t = real_types.get(name)
        if real_t is None:
            errors.append(
                f"Type '{name}' is in mock but not in real schema "
                f"(remove it from the mock or add it to Mina_graphql)"
            )
            continue
        if mock_t.get("kind") != real_t.get("kind"):
            errors.append(
                f"Type '{name}' has kind {mock_t.get('kind')!r} in mock "
                f"but {real_t.get('kind')!r} in real"
            )
            continue

        # Output-object fields
        mfields = fields_by_name(mock_t, "fields")
        rfields = fields_by_name(real_t, "fields")
        for fname, mf in mfields.items():
            rf = rfields.get(fname)
            if rf is None:
                errors.append(
                    f"Field '{name}.{fname}' is in mock but not in real schema"
                )
                continue
            if normalize_type_ref(mf.get("type")) != normalize_type_ref(
                rf.get("type")
            ):
                errors.append(
                    f"Field '{name}.{fname}' return type diverges: "
                    f"mock={mf.get('type')} real={rf.get('type')}"
                )
            if normalize_args(mf.get("args")) != normalize_args(rf.get("args")):
                errors.append(
                    f"Field '{name}.{fname}' argument list diverges between mock and real"
                )

        # Input-object fields
        m_inputs = fields_by_name(mock_t, "inputFields")
        r_inputs = fields_by_name(real_t, "inputFields")
        for fname, mf in m_inputs.items():
            rf = r_inputs.get(fname)
            if rf is None:
                errors.append(
                    f"Input field '{name}.{fname}' is in mock but not in real schema"
                )
                continue
            if normalize_type_ref(mf.get("type")) != normalize_type_ref(
                rf.get("type")
            ):
                errors.append(
                    f"Input field '{name}.{fname}' type diverges: "
                    f"mock={mf.get('type')} real={rf.get('type')}"
                )

        # Enum values
        m_enum = {v["name"] for v in (mock_t.get("enumValues") or [])}
        r_enum = {v["name"] for v in (real_t.get("enumValues") or [])}
        for v in m_enum - r_enum:
            errors.append(
                f"Enum value '{name}.{v}' is in mock but not in real schema"
            )

    print(
        f"Mock schema: {len(mock_types)} types, "
        f"{sum(len(t.get('fields') or []) for t in mock_types.values())} fields"
    )
    print(
        f"Real schema: {len(real_types)} types, "
        f"{sum(len(t.get('fields') or []) for t in real_types.values())} fields"
    )

    if errors:
        print(f"\nFOUND {len(errors)} divergence(s):")
        for e in errors:
            print(f"  - {e}")
        print(
            "\nThe mock GraphQL schema must be a structural subset of the real "
            "daemon schema. Either remove the divergent fields/types from the "
            "mock, or land the matching change to Mina_graphql first."
        )
        sys.exit(1)

    print("\nMock schema is a structural subset of real schema.")
    sys.exit(0)


def main(argv):
    if len(argv) != 3:
        sys.stderr.write(
            f"usage: {argv[0]} <mock_schema.json> <graphql_schema.json>\n"
        )
        sys.exit(2)
    check_subset(argv[1], argv[2])


if __name__ == "__main__":
    main(sys.argv)
