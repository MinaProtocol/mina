//! # Amounts Module
//!
//! Pure parsing helpers for Mina amount and duration DSLs. Provides:
//!
//! * a Mina amount DSL parser (`<number>mina` / `<integer>nanomina`) using exact
//!   integer arithmetic (no floating point),
//! * formatting of a nanomina integer as a 9-decimal mina string,
//! * a tier account specifier parser (`whale-0` -> `("whale", 0)`),
//! * an ISO-8601 `PT<number>S` duration parser.
//!
//! To avoid adding a new crate dependency the grammars are parsed by hand rather
//! than with the `regex` crate.
//!
//! These functions have no consumer in the `minimina` binary yet (balances
//! currently enter minimina only via a verbatim `--genesis-ledger` JSON file);
//! they are exposed through the library target so their doc examples run as
//! doctests and a real caller can adopt them later.

use std::fmt;

/// Error returned by the parsers in this module.
///
/// Mirrors the `INVALID_ARGUMENT` topology error raised by the Python source: it
/// carries a human-readable message describing why the input could not be parsed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AmountParseError {
    pub message: String,
}

impl AmountParseError {
    fn new(message: impl Into<String>) -> Self {
        AmountParseError {
            message: message.into(),
        }
    }
}

impl fmt::Display for AmountParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for AmountParseError {}

/// A mina is 10^9 nanomina; nanomina is the smallest representable unit.
const NANOMINA_PER_MINA: u64 = 1_000_000_000;
/// A mina is 10^9 nanomina, so 9 fractional digits is exact.
const NANOMINA_DECIMALS: usize = 9;

/// Return `true` if `s` is non-empty and made up only of ASCII digits.
fn is_all_digits(s: &str) -> bool {
    !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit())
}

/// Parse a Mina amount DSL string to an integer number of nanomina.
///
/// Accepts `<int>mina`, a fractional `<int>.<frac>mina`, or `<int>nanomina`.
/// Fractional mina is converted exactly via integer arithmetic; more than 9
/// fractional digits is sub-nanomina precision and rejected, since nanomina is
/// the smallest representable unit.
///
/// ```
/// use minimina::amounts::amount_dsl_to_nanomina;
///
/// // Whole mina: 1 mina == 10^9 nanomina.
/// assert_eq!(amount_dsl_to_nanomina("1mina").unwrap(), 1_000_000_000);
///
/// // Fractional mina, converted exactly.
/// assert_eq!(amount_dsl_to_nanomina("0.25mina").unwrap(), 250_000_000);
///
/// // Nanomina passes through verbatim.
/// assert_eq!(amount_dsl_to_nanomina("5nanomina").unwrap(), 5);
///
/// // Sub-nanomina precision (>9 fractional digits) is rejected.
/// assert!(amount_dsl_to_nanomina("1.1234567890mina").is_err());
///
/// // A bare number with no unit is rejected.
/// assert!(amount_dsl_to_nanomina("42").is_err());
/// ```
pub fn amount_dsl_to_nanomina(amount_str: &str) -> Result<u64, AmountParseError> {
    let invalid = || {
        AmountParseError::new(format!(
            "Invalid amount: {amount_str:?}. Expected format: \
             <number>mina (may be fractional) or <integer>nanomina"
        ))
    };

    // Check the `nanomina` branch first: "5nanomina" also ends with "mina".
    if let Some(digits) = amount_str.strip_suffix("nanomina") {
        if !is_all_digits(digits) {
            return Err(invalid());
        }
        return digits.parse::<u64>().map_err(|_| {
            AmountParseError::new(format!(
                "Amount {amount_str:?} is out of range for u64 nanomina"
            ))
        });
    }

    // The `mina` branch: `<int>` or `<int>.<frac>`.
    if let Some(number) = amount_str.strip_suffix("mina") {
        let (int_str, frac_str): (&str, Option<&str>) = match number.split_once('.') {
            Some((i, f)) => (i, Some(f)),
            None => (number, None),
        };

        if !is_all_digits(int_str) {
            return Err(invalid());
        }
        if let Some(frac) = frac_str {
            if !is_all_digits(frac) {
                return Err(invalid());
            }
            if frac.len() > NANOMINA_DECIMALS {
                return Err(AmountParseError::new(format!(
                    "Amount {amount_str:?} has sub-nanomina precision: mina supports \
                     at most {NANOMINA_DECIMALS} fractional digits."
                )));
            }
        }

        let int_part = int_str.parse::<u64>().map_err(|_| {
            AmountParseError::new(format!(
                "Amount {amount_str:?} is out of range for u64 nanomina"
            ))
        })?;

        // Right-pad the fractional digits to exactly 9 places, then parse.
        let frac_nanomina: u64 = match frac_str {
            Some(frac) => {
                let mut padded = String::with_capacity(NANOMINA_DECIMALS);
                padded.push_str(frac);
                while padded.len() < NANOMINA_DECIMALS {
                    padded.push('0');
                }
                padded
                    .parse::<u64>()
                    .expect("padded fractional digits parse")
            }
            None => 0,
        };

        let whole = int_part.checked_mul(NANOMINA_PER_MINA).ok_or_else(|| {
            AmountParseError::new(format!(
                "Amount {amount_str:?} is out of range for u64 nanomina"
            ))
        })?;
        return whole.checked_add(frac_nanomina).ok_or_else(|| {
            AmountParseError::new(format!(
                "Amount {amount_str:?} is out of range for u64 nanomina"
            ))
        });
    }

    Err(invalid())
}

/// Format an integer nanomina amount as a 9-decimal mina string (for `-amount`).
pub fn nanomina_to_decimal_mina(nanomina: u64) -> String {
    let int_part = nanomina / NANOMINA_PER_MINA;
    let frac_part = nanomina % NANOMINA_PER_MINA;
    format!("{int_part}.{frac_part:09}")
}

/// Convert a Mina amount DSL string to a 9-decimal-place mina string.
///
/// Uses exact integer arithmetic (no floating point).
pub fn convert_balance_to_decimal_mina(balance_str: &str) -> Result<String, AmountParseError> {
    Ok(nanomina_to_decimal_mina(amount_dsl_to_nanomina(
        balance_str,
    )?))
}

/// Parse a tier account specifier like `whale-0` into `(tier, index)`.
///
/// Grammar: `^([a-zA-Z_][a-zA-Z0-9_]*)-(\d+)$`.
pub fn parse_account_spec(spec: &str) -> Result<(String, u32), AmountParseError> {
    let invalid = || {
        AmountParseError::new(format!(
            "Invalid account specifier: {spec:?}. Expected format: tier-index (e.g. 'whale-0')"
        ))
    };

    // Split on the last '-', since the tier itself never contains '-'.
    let (tier, index_str) = spec.rsplit_once('-').ok_or_else(invalid)?;

    // Tier: first char is a letter or underscore, rest alphanumeric or underscore.
    let mut chars = tier.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return Err(invalid()),
    }
    if !chars.all(|c| c.is_ascii_alphanumeric() || c == '_') {
        return Err(invalid());
    }

    if !is_all_digits(index_str) {
        return Err(invalid());
    }
    let index = index_str.parse::<u32>().map_err(|_| {
        AmountParseError::new(format!("Account index in {spec:?} is out of range for u32"))
    })?;

    Ok((tier.to_string(), index))
}

/// Parse an ISO-8601 `PT<number>S` duration string into seconds.
///
/// Grammar (`ISO_DURATION_RE`): `^PT(\d+(?:\.\d+)?)S$`.
pub fn parse_iso_duration(dur_str: &str) -> Result<f64, AmountParseError> {
    let invalid = || AmountParseError::new(format!("Cannot parse ISO duration: {dur_str:?}"));

    let inner = dur_str
        .strip_prefix("PT")
        .and_then(|rest| rest.strip_suffix('S'))
        .ok_or_else(invalid)?;

    // `\d+(?:\.\d+)?`: whole part required, optional `.` + whole fractional part.
    let valid_number = match inner.split_once('.') {
        Some((int, frac)) => is_all_digits(int) && is_all_digits(frac),
        None => is_all_digits(inner),
    };
    if !valid_number {
        return Err(invalid());
    }

    inner.parse::<f64>().map_err(|_| invalid())
}

#[cfg(test)]
mod tests {
    use super::*;
    use quickcheck::quickcheck;

    // --- amount_dsl_to_nanomina: property tests -----------------------------

    quickcheck! {
        /// Any `<n>nanomina` parses back to exactly `n`.
        fn prop_nanomina_roundtrips(n: u64) -> bool {
            amount_dsl_to_nanomina(&format!("{n}nanomina")) == Ok(n)
        }
    }

    quickcheck! {
        /// Any `<n>mina` or `<n>.<m>mina` (with `m` at 9-digit precision)
        /// converts to exactly `n * 10^9 + m` nanomina via integer arithmetic.
        fn prop_mina_exact(int_part: u32, frac: Option<u32>) -> bool {
            let (input, expected) = match frac {
                // `frac % 10^9` keeps `m` within the 9 fractional digits that
                // format!("{:09}") emits, i.e. within nanomina precision.
                Some(f) => {
                    let f = f % NANOMINA_PER_MINA as u32;
                    (
                        format!("{int_part}.{f:09}mina"),
                        int_part as u64 * NANOMINA_PER_MINA + f as u64,
                    )
                }
                None => (format!("{int_part}mina"), int_part as u64 * NANOMINA_PER_MINA),
            };
            amount_dsl_to_nanomina(&input) == Ok(expected)
        }
    }

    // --- amount_dsl_to_nanomina ---------------------------------------------

    #[test]
    fn dsl_whole_mina() {
        assert_eq!(amount_dsl_to_nanomina("1mina").unwrap(), 1_000_000_000);
    }

    #[test]
    fn dsl_fractional_mina() {
        assert_eq!(amount_dsl_to_nanomina("0.25mina").unwrap(), 250_000_000);
    }

    #[test]
    fn dsl_fractional_mina_gt_one() {
        assert_eq!(amount_dsl_to_nanomina("3.3mina").unwrap(), 3_300_000_000);
    }

    #[test]
    fn dsl_nanomina() {
        assert_eq!(amount_dsl_to_nanomina("5nanomina").unwrap(), 5);
    }

    #[test]
    fn dsl_zero_mina() {
        assert_eq!(amount_dsl_to_nanomina("0mina").unwrap(), 0);
    }

    #[test]
    fn dsl_zero_nanomina() {
        assert_eq!(amount_dsl_to_nanomina("0nanomina").unwrap(), 0);
    }

    #[test]
    fn dsl_full_nine_fractional_digits() {
        // 0.123456789 mina == 123456789 nanomina, exact.
        assert_eq!(
            amount_dsl_to_nanomina("0.123456789mina").unwrap(),
            123_456_789
        );
    }

    #[test]
    fn dsl_max_precision_boundary() {
        // Exactly 9 fractional digits is allowed.
        assert_eq!(
            amount_dsl_to_nanomina("1.000000001mina").unwrap(),
            1_000_000_001
        );
    }

    #[test]
    fn dsl_ten_fractional_digits_rejected() {
        // 10 fractional digits is sub-nanomina precision -> error.
        assert!(amount_dsl_to_nanomina("1.1234567890mina").is_err());
    }

    #[test]
    fn dsl_large_value() {
        assert_eq!(
            amount_dsl_to_nanomina("11550000mina").unwrap(),
            11_550_000_000_000_000
        );
    }

    #[test]
    fn dsl_invalid_strings() {
        for bad in [
            "",            // empty
            "mina",        // missing number
            "nanomina",    // missing number
            "abc",         // garbage
            "1",           // missing unit
            "1.5",         // missing unit
            "-1mina",      // negative-looking
            "-5nanomina",  // negative-looking
            "1.mina",      // empty fractional
            ".5mina",      // empty integer part
            "1.5nanomina", // fractional nanomina not allowed
            "1mina2",      // trailing junk
            "1 mina",      // space
            "1MINA",       // wrong case
            "1.2.3mina",   // two dots
        ] {
            assert!(
                amount_dsl_to_nanomina(bad).is_err(),
                "expected {bad:?} to be rejected"
            );
        }
    }

    // --- nanomina_to_decimal_mina -------------------------------------------

    #[test]
    fn nanomina_format_fractional() {
        assert_eq!(nanomina_to_decimal_mina(250_000_000), "0.250000000");
    }

    #[test]
    fn nanomina_format_whole() {
        assert_eq!(nanomina_to_decimal_mina(1_000_000_000), "1.000000000");
    }

    #[test]
    fn nanomina_format_smallest() {
        assert_eq!(nanomina_to_decimal_mina(5), "0.000000005");
    }

    #[test]
    fn nanomina_format_zero() {
        assert_eq!(nanomina_to_decimal_mina(0), "0.000000000");
    }

    // --- convert_balance_to_decimal_mina ------------------------------------

    #[test]
    fn convert_balance_whole_mina() {
        assert_eq!(
            convert_balance_to_decimal_mina("11550000mina").unwrap(),
            "11550000.000000000"
        );
    }

    #[test]
    fn convert_balance_fractional_mina() {
        assert_eq!(
            convert_balance_to_decimal_mina("0.25mina").unwrap(),
            "0.250000000"
        );
    }

    #[test]
    fn convert_balance_thousand_nanomina() {
        assert_eq!(
            convert_balance_to_decimal_mina("1000nanomina").unwrap(),
            "0.000001000"
        );
    }

    #[test]
    fn convert_balance_five_nanomina() {
        assert_eq!(
            convert_balance_to_decimal_mina("5nanomina").unwrap(),
            "0.000000005"
        );
    }

    #[test]
    fn convert_balance_invalid() {
        assert!(convert_balance_to_decimal_mina("bogus").is_err());
    }

    // --- parse_account_spec -------------------------------------------------

    #[test]
    fn account_spec_whale() {
        assert_eq!(
            parse_account_spec("whale-0").unwrap(),
            ("whale".to_string(), 0)
        );
    }

    #[test]
    fn account_spec_fish() {
        assert_eq!(
            parse_account_spec("fish-2").unwrap(),
            ("fish".to_string(), 2)
        );
    }

    #[test]
    fn account_spec_underscore_tier() {
        assert_eq!(
            parse_account_spec("_priv_tier1-42").unwrap(),
            ("_priv_tier1".to_string(), 42)
        );
    }

    #[test]
    fn account_spec_invalid() {
        for bad in [
            "",          // empty
            "whale",     // no index
            "whale-",    // empty index
            "-0",        // empty tier
            "0whale-0",  // tier starts with digit
            "whale-0-1", // handled by rsplit, but "whale-0" tier is invalid... see note
            "wha le-0",  // space in tier
            "whale-x",   // non-numeric index
            "whale-1.5", // fractional index
            "whale--1",  // negative-looking index
        ] {
            assert!(
                parse_account_spec(bad).is_err(),
                "expected {bad:?} to be rejected"
            );
        }
    }

    // --- parse_iso_duration -------------------------------------------------

    #[test]
    fn iso_duration_one_second() {
        assert_eq!(parse_iso_duration("PT1S").unwrap(), 1.0);
    }

    #[test]
    fn iso_duration_half_second() {
        assert_eq!(parse_iso_duration("PT0.5S").unwrap(), 0.5);
    }

    #[test]
    fn iso_duration_multi_digit() {
        assert_eq!(parse_iso_duration("PT180S").unwrap(), 180.0);
    }

    #[test]
    fn iso_duration_invalid() {
        for bad in [
            "",         // empty
            "PT1",      // missing S
            "1S",       // missing PT
            "PTS",      // missing number
            "PT.5S",    // empty integer part
            "PT1.S",    // empty fractional part
            "PT1MS",    // wrong unit
            "P1S",      // missing T
            "pt1s",     // wrong case
            "PT-1S",    // negative-looking
            "PT1.2.3S", // two dots
        ] {
            assert!(
                parse_iso_duration(bad).is_err(),
                "expected {bad:?} to be rejected"
            );
        }
    }
}
