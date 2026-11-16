# lmsr-fe

**Pitch:** A logarithmic market scoring rule (LMSR) prediction-market maker
written in Fe: a reusable WAD fixed-point `exp`/`ln` library, an N-outcome
LMSR whose rounding never lets the market maker lose money to dust, and a
minimal on-chain market contract built on it.

> Status: work in progress for the [Fe Builders Challenge](https://fe-lang.org/contest/)
> (build window 3-24 Nov 2026). Milestone M2 is done; see [Limitations](#limitations).

## The problem

LMSR (Hanson, 2003) is the standard automated market maker for prediction
markets: it always quotes a price, its prices are probabilities that sum to 1,
and the market creator's worst-case loss is bounded by `b * ln(n)`. On the EVM
it is awkward, because it needs `exp` and `ln` in fixed point, and naive
`exp(q_i / b)` overflows quickly. Every rounding error is also an attack
surface: if a buy is ever charged a wei less than the exact cost, or a sell
pays a wei more, then repeated round trips drain the maker.

## Approach

- **WAD fixed point (1e18)** on top of Fe std's 512-bit `mul_div` /
  `mul_div_ceil`, so `a * b / c` never overflows before the division.
- **Unsigned-only transcendentals.** LMSR is evaluated in max-shifted
  log-sum-exp form, so `exp` is only ever called on non-positive arguments and
  `ln` only on arguments >= 1. No signed fixed point is needed:
  - `exp_neg_wad(x) = exp(-x)`: range reduction `x = k*ln2 + r`, Taylor series
    for `exp(r)` with `r < ln 2`, then `2^-k / exp(r)`.
  - `ln_wad(x)` for `x >= 1`: `x = 2^k * y`, `ln y = 2*atanh((y-1)/(y+1))`, with
    the series run at 1e36 internal precision; result within about 1 wei.
- **N-outcome LMSR via log-sum-exp with a max shift:**

  ```
  C(q)   = m + b * ln( sum_i exp(-(m - q_i) / b) ),   m = max_i q_i
  p_i(q) = exp(-(m - q_i) / b) / sum_j exp(-(m - q_j) / b)
  ```

  Every exponent is <= 0 and the sum is in `[1, n]`, so nothing overflows for
  any book size. A 4-outcome book with a 5000-share gap (`exp(-50)`) is in
  the test vectors.
- **Maker-favour rounding.** `cost_err_n(b, n)` is a documented error budget
  per evaluation (64 wei per outcome per 1.0 of `b`, which is generous
  compared with the measured few wei). Then:
  - buy charges `max(C(q') - C(q), 0) + cost_err_n`, which is >= the exact cost;
  - sell pays `max(C(q) - C(q') - cost_err_n, 0)`, which is <= the exact payout;
  - both use the same deterministic `C`, so buying and then selling the same
    amount loses exactly `2 * cost_err_n` (or more when the sell saturates at
    0). A round trip can never profit, and dust trades can never revert or pay out.
  - prices are rounded down, so they sum to at most 1.0 (within 16 wei per
    outcome in the tests).
- **Bounded loss on-chain.** The `Market` contract refuses to deploy unless it
  is sent `lmsr_max_loss(b, n) >= b * ln(n)` wei as a subsidy. With every
  trade rounded towards the maker, the balance always covers the winning
  outcome's outstanding shares.

## Fe highlight

Const generics and fixed-size arrays let one N-outcome implementation serve
any market size, and the contract keeps a single storage layout (capacity 8)
while trading only `n` live outcomes:

```fe
pub fn lmsr_cost_n<const N: usize>(_ q: [u256; N], _ n: usize, _ b: u256) -> u256 {
    let (m, s) = sum_exp_n(q, n, b)
    m + wad_mul_down(b, ln_wad(s))
}
```

Fe's effect system (`uses (ctx, mut call, mut q, ...)`) makes each message
handler declare exactly which storage fields and capabilities it touches. For
example, `Price` and `QuoteBuy` can't write storage or send ETH, and the type
checker enforces that.

## Architecture

| Path | Contents |
| --- | --- |
| `src/lib.fe` | WAD math (`wad_mul/div_{up,down}`, `wad_sqrt`), `exp_neg_wad`, `ln_wad`; 2-outcome LMSR (`lmsr_cost`, `lmsr_price1`, `lmsr_buy1_cost`, `lmsr_sell1_payout`); N-outcome LMSR (`lmsr_cost_n`, `lmsr_price_n`, `lmsr_buy_cost_n`, `lmsr_sell_payout_n`, `lmsr_max_loss`, `cost_err_n`). |
| `src/market.fe` | `Market` contract: one market, 2..=8 outcomes, ETH collateral (1 share unit pays 1 wei if it wins). Messages: `buy`, `sell`, `quoteBuy`, `quoteSell`, `price`, `sharesOf`, `outstanding`, `resolve` (creator is the oracle), `redeem`, `sweep`. Events `Traded`, `Resolved`. |
| `src/tests.fe` | Unit tests for the math, 2-outcome LMSR, sell/round trip, and N-outcome properties. |
| `src/vectors.fe` | **Generated** by `scripts/vectors.py`: N-outcome reference vectors (n = 3, 4, 5 in a capacity-8 array). |
| `src/market_tests.fe` | Contract tests that deploy `Market` on Fe's test EVM and trade against it. |
| `scripts/vectors.py` | Exact reference values from Python `decimal` at 80 digits, floored to wei. |

Contract flow: the creator deploys `Market(b, n)` with the subsidy. Traders
then `buy` (paying ETH, with any excess refunded to `refund_to`) and `sell`
(payout to `to`). Next the creator calls `resolve(winner)`, holders call
`redeem(to)`, and finally the creator calls `sweep(to)` to take back
everything above the still-unredeemed winning shares. State is updated before
any ETH transfer.

## Build and test

```sh
# Fe 26.5.0
curl -fsSL https://raw.githubusercontent.com/argotorg/fe/master/feup/feup.sh | bash -s -- --version v26.5.0
fe --version      # fe 26.5.0 (3dab95f)
fe fmt --check
fe test           # 35 tests
fe build          # writes out/Market.bin, out/Market.runtime.bin, out/Market.abi.json

# Optional: regenerate the N-outcome reference vectors (Python 3, stdlib only)
python3 scripts/vectors.py && fe fmt && fe test
```

CI (`.github/workflows/ci.yml`) runs `fe fmt --check`, `fe test` and
`fe build` with Fe 26.5.0.

## Demo

Reproducible CLI demo: `fe test` deploys the market on the test EVM, buys,
gets the excess refunded, sells back at a strict loss, resolves, redeems the
winning shares 1:1 and sweeps the remaining subsidy (see
`market_resolve_redeem_sweep` in `src/market_tests.fe`). A short screen
recording is planned for the submission.

## Limitations

- **Trusted resolver.** The creator resolves the market. There is no oracle,
  dispute window or timeout.
- **ETH collateral only.** There is no ERC-20 collateral and no transferable
  share tokens yet; shares are internal balances.
- **Error budget is conservative but not formally proven.** The `exp`/`ln`
  error bounds are checked against high-precision vectors, not machine-proved.
  `COST_ERR_PER_B = 64` wei per outcome per 1.0 of `b` is well above the
  observed error.
- **Gas** has not been optimised or measured yet. Every trade evaluates `C`
  twice, which is O(n) `exp` calls plus one `ln`.
- **Not audited.** This is a contest prototype; do not use it with real funds.

## Declaration

- **Pre-existing work:** None. The repository started from the official
  `fe-lang/builders-challenge-starter` (vault example removed). All LMSR and
  math code was written during the contest window (from 15 Nov 2026).
- **Third-party code:** Fe std (`core::num::mul_div`, `mul_div_ceil`, `isqrt`,
  `std::evm`). CI workflow and LICENSE come from the starter (Apache-2.0).
- **AI assistance:** Yes. AI coding assistants were used to write and test
  the code and docs, under the author's direction.

## Team

Ali Ghaedi (solo).

## License

Apache-2.0 (see `LICENSE`).
