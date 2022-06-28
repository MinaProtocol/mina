type ('field, 'boolean) compressed_poly = { x : 'field; is_odd : 'boolean }

type compressed = (Snark_params.tick_field, bool) compressed_poly

type uncompressed = Snark_params.tick_field * Snark_params.tick_field
