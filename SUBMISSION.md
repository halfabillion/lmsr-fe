# Submission notes (internal checklist; README.md is the jury-facing doc)

Contest: Fe Builders Challenge. Registration was submitted on 15 Nov 2026; the
project ID and private submission link will arrive by email at
batchandledger@mail.grokbot.com. Submission closes **24 Nov 2026 23:59 UTC**.
Submission form: https://docs.google.com/forms/d/e/1FAIpQLSd2pqUkJzFpZMu5FVQP-NtetrIoB6nI-pHG1MLTOQhCpsLKqg/viewform
(use the personal link from the registration email).

## Milestones

- M0 (e6be06e): WAD core on std 512-bit mul_div; 5 tests.
- M1 (c312ccc): exp_neg_wad / ln_wad, 2-outcome LMSR cost/price/buy; 11 tests.
- M2 (f1e0d45, a6bf553, 66fd683 + docs): 2-outcome sell with maker-favour
  rounding; N-outcome LMSR (log-sum-exp with max shift), Python-generated
  vectors; `Market` contract (buy/sell/quote/price/resolve/redeem/sweep);
  35 tests green; `fe build` OK.
- M3 (ec4fc30, 81c357d, 10f5fee, 2142089 + docs): resolve-by deadline and
  cancel path with net-collateral refunds (pro-rata if short) and a reserve-
  keeping sweep, 11 cancel tests with a Trader proxy; 40 seeded-random
  property vectors plus 3 random contract trade sequences; gas probe at
  n = 2, 4, 8. 90 tests green; `fe build` OK.

## Checklist for the form

- [ ] Public GitHub repo with OSI license (Apache-2.0 is in place). Not yet
      published; needs Ali's OK and his GitHub account.
- [ ] Full commit SHA to review: fill in after the final commit.
- [x] `fe.toml` + exact Fe version: fe 26.5.0 (3dab95f).
- [x] Reproducible build/test instructions and automated tests (README).
- [x] README: problem, approach, architecture, limitations.
- [x] One-sentence pitch + Fe highlight (README).
- [x] Demo: `scripts/demo.sh` compiles the Fe Market, deploys it to a local anvil
      chain and runs a full lifecycle plus the cancel/refund path with cast;
      captured output in `scripts/demo-output.txt`.
- [x] Declaration of pre-existing work, third-party code, AI assistance (README).

## M3 ideas (priority order)

1. [x] Gas measurement for buy/sell at n = 2, 4, 8 (2142089; README "Gas").
   [ ] Cheap optimisations (share the `exp` terms between the two cost
   evaluations) are still open.
2. [x] Property-style tests (10f5fee): 40 seeded-random books/amounts checking
   buy >= exact and sell <= exact; 3 random trade sequences checking balance
   >= max outstanding after each step.
3. [x] Resolution timeout / cancel path (ec4fc30). Refunds are net collateral
   paid (pro-rata if short) rather than at the last prices, which could be
   gamed by pushing the price just before cancel. The solvency argument is in
   the README.
4. Optional ERC-20 collateral.
5. Demo recording, then publish the repo and submit.

Payout if placed: USDC on Ethereum to Ali's Phantom EVM address 0xd978…278A
(the organisers request it by email after results).
