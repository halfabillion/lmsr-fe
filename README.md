# lmsr-fe

**Pitch:** A logarithmic market scoring rule (LMSR) prediction-market maker
written in Fe: a reusable WAD fixed-point `exp`/`ln` library, an N-outcome
LMSR whose rounding never lets the market maker lose money to dust, and a
minimal on-chain market contract built on it.

> Status: work in progress for the [Fe Builders Challenge](https://fe-lang.org/contest/)
> (build window 3-24 Nov 2026). Milestones M2 and M3 (cancel path, property tests, gas probe) are done; see [Limitations](#limitations).

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
  outcome's outstanding shares. Seeded-random trade sequences check this
  after every step (`src/prop_market_tests.fe`).
- **Resolution timeout / cancel path.** Each market has a resolve-by
  `deadline` (unix seconds, set at deploy). If the creator has not resolved by
  then, *anyone* can `cancel()`, and every trader can claim one `refund(to)`.

  **Refund rule:** each trader's *net collateral paid*, i.e. total ETH kept on
  their buys minus total ETH received on their sells, floored at 0 (tracked
  per trader on every trade, together with the running sum `T` of those
  positive nets). At cancel the contract snapshots `P = min(balance, T)` and
  pays each trader `floor(net_i * P / T)`. Normally `P = T` and everyone gets
  their net stake back exactly; if traders who sold at a profit took out more
  than the subsidy, refunds are scaled down pro-rata.

  **Why it is solvent:** the refunds sum to `sum_i floor(net_i * P / T) <=
  P * (sum_i net_i) / T = P <= balance`, so the balance always covers every
  claim whatever order they arrive in. After cancel the creator can `sweep`
  at any time, but only `balance - (P - refunded)`. That always leaves
  the full unclaimed reserve, so no second grace period is needed. `resolve`
  is rejected after `cancel`, `cancel` is rejected after `resolve`, trading
  and `redeem` are rejected after `cancel`, and each trader can claim only once.
  Net-paid refunds (rather than refunds at the last prices) cannot be gamed by
  pushing the price just before cancelling, because a trade made right before
  cancel is refunded at exactly what it cost.

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
| `src/market.fe` | `Market` contract: one market, 2..=8 outcomes, ETH collateral (1 share unit pays 1 wei if it wins). Messages: `buy`, `sell`, `quoteBuy`, `quoteSell`, `price`, `sharesOf`, `outstanding`, `resolve` (creator is the oracle), `redeem`, `sweep`, plus the M3 cancel path `cancel`, `refund`, `refundOf`, `netPaid`. Events `Traded`, `Resolved`, `Cancelled`, `Refunded`. |
| `src/tests.fe` | Unit tests for the math, 2-outcome LMSR, sell/round trip, and N-outcome properties. |
| `src/vectors.fe` | **Generated** by `scripts/vectors.py`: 6 hand-picked N-outcome reference vectors (n = 3, 4, 5 in a capacity-8 array) plus 40 seeded-random property vectors (n = 2..8, wei-level `b`, books and trade sizes) checking buy cost >= exact and sell payout <= exact, each within `2 * cost_err_n + 1`. |
| `src/prop_market_tests.fe` | **Generated**: three seeded-random 30-step buy/sell sequences (n = 3, 5, 8) against the deployed `Market`, asserting balance >= the largest outstanding share count after every step. |
| `src/market_tests.fe` | Contract tests that deploy `Market` on Fe's test EVM and trade against it. |
| `src/cancel_tests.fe` | Cancel-path tests, using a test-only `Trader` proxy contract so the market sees several distinct traders. |
| `src/gas_tests.fe` | Gas probe for buy/sell at n = 2, 4, 8 (see [Gas](#gas)). |
| `scripts/vectors.py` | Exact reference values from Python `decimal` at 80 digits, floored to wei; fixed seed `20261116`. |

Contract flow: the creator deploys `Market(b, n, resolve_by)` with the subsidy. Traders
then `buy` (paying ETH, with any excess refunded to `refund_to`) and `sell`
(payout to `to`). Next the creator calls `resolve(winner)`, holders call
`redeem(to)`, and finally the creator calls `sweep(to)` to take back
everything above the still-unredeemed winning shares. If nobody has resolved
by `resolve_by`, anyone calls `cancel()`, traders call `refund(to)`, and the
creator sweeps the excess above the unclaimed refunds. State is updated before
any ETH transfer.

## Build and test

```sh
# Fe 26.5.0
curl -fsSL https://raw.githubusercontent.com/argotorg/fe/master/feup/feup.sh | bash -s -- --version v26.5.0
fe --version      # fe 26.5.0 (3dab95f)
fe fmt --check
fe test           # 90 tests
fe build          # writes out/Market.{bin,runtime.bin,abi.json} (and the test-only Trader proxy)

# Optional: regenerate the reference + property vectors (Python 3, stdlib only)
python3 scripts/vectors.py && fe fmt && fe test
```

Checks: `fe fmt --check`, `fe test` and `fe build` with Fe 26.5.0.

## Demo

Reproducible CLI demo: `fe test` deploys the market on the test EVM, buys,
gets the excess refunded, sells back at a strict loss, resolves, redeems the
winning shares 1:1 and sweeps the remaining subsidy (see
`market_resolve_redeem_sweep` in `src/market_tests.fe`). A short screen
recording is planned for the submission.

## Gas

`fe test` has no gas report, so `src/gas_tests.fe` reads the `GAS` opcode
around each call and emits `GasUsed` events (`fe test -f gas_ --show-logs`).
On a book that already has one trade, with Fe 26.5.0 at the default `-O1`
(`-O2` is within ~16 gas). Figures include the outer CALL overhead and, for
buys, the ETH value transfer and the refund of the excess:

| n | buy | sell |
| --- | --- | --- |
| 2 | ~100.6k | ~72.0k |
| 4 | ~122.1k | ~93.5k |
| 8 | ~169.7k | ~142.0k |

Cost grows by roughly 12k gas per extra outcome, because each trade evaluates
`C` twice (2n `exp` plus 2 `ln`) and reads the 8-slot book. The obvious next
optimisation is to share the `exp` terms of untouched outcomes between the two
`C` evaluations.

## Limitations

- **Trusted resolver.** The creator resolves the market. There is no oracle or
  dispute window. The resolve-by deadline and the cancel path stop a missing
  resolver from locking funds, but not a dishonest one.
- **Deadline semantics, and testing it.** Fe's test EVM has a fixed clock
  (timestamp 1, block 0) that tests cannot advance. So `init` deliberately
  does not require `resolve_by` to be in the future: the tests deploy an
  already-expired market (`resolve_by = 1`) for the "after deadline" cases
  and a far-future one (`4_000_000_000`) for "before deadline". For the same
  reason, trading is not closed at the deadline: it stays open until someone
  calls `resolve` or `cancel`, and the creator may still resolve late if
  nobody has cancelled yet. A production version would add a separate
  trading-close time. With net-paid refunds, trading after the deadline cannot
  extract value through a cancel.
- **Cancel refunds ignore positions.** A refund returns net ETH paid, not the
  value of the shares held, so traders who sold at a profit keep that profit
  (and, if it exceeded the subsidy, the others are refunded pro-rata).
- **ETH collateral only.** There is no ERC-20 collateral and no transferable
  share tokens yet; shares are internal balances.
- **Error budget is conservative but not formally proven.** The `exp`/`ln`
  error bounds are checked against high-precision vectors, not machine-proved.
  `COST_ERR_PER_B = 64` wei per outcome per 1.0 of `b` is well above the
  observed error.
- **Gas** is measured (see [Gas](#gas)) but not optimised.
- **Test-only `Trader` proxy** lives in `src/cancel_tests.fe` and is also
  emitted by `fe build`. It is not part of the deployable market.
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


## On-chain demo

`scripts/demo.sh` (needs `fe` and Foundry) builds the contract, starts a local
anvil chain and drives two markets with `cast`: a 3-outcome market through
buy / overpay-refund / sell / resolve / redeem / sweep, and a 2-outcome market
whose resolve-by deadline has passed through cancel / refund. Prices printed
after each trade always sum to 1. Sample output: `scripts/demo-output.txt`.
