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
- M3 (to do): see below.

## Checklist for the form

- [ ] Public GitHub repo with OSI license (Apache-2.0 is in place). Not yet
      published; needs Ali's OK and his GitHub account.
- [ ] Full commit SHA to review: fill in after the final commit.
- [x] `fe.toml` + exact Fe version: fe 26.5.0 (3dab95f).
- [x] Reproducible build/test instructions and automated tests (README).
- [x] README: problem, approach, architecture, limitations.
- [x] One-sentence pitch + Fe highlight (README).
- [ ] Demo: the CLI demo is in place (`fe test`); optionally add a short
      recording.
- [x] Declaration of pre-existing work, third-party code, AI assistance (README).

## M3 ideas (priority order)

1. Gas measurement for buy/sell at n = 2, 4, 8, plus cheap optimisations
   (cache `exp` terms between the two cost evaluations).
2. Property-style tests: many random books and amounts from
   scripts/vectors.py, checking that buy >= exact and sell <= exact, and that
   the contract balance stays >= max outstanding shares after random trade
   sequences.
3. Resolution timeout / cancel path (refund at last prices), so a missing
   resolver can't lock funds.
4. Optional ERC-20 collateral.
5. Demo recording, then publish the repo and submit.

Payout if placed: USDC on Ethereum to Ali's Phantom EVM address 0xd978…278A
(the organisers request it by email after results).
