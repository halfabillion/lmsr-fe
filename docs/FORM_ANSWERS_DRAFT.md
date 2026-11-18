# Fe Builders Challenge — submission form answers (draft only)

This is a local draft for the official form:

https://docs.google.com/forms/d/e/1FAIpQLSd2pqUkJzFpZMu5FVQP-NtetrIoB6nI-pHG1MLTOQhCpsLKqg/viewform

Do not submit until Ali says go. Do not create or push a GitHub repo update
until he says go. The public viewform was fetched read-only on 18 Nov 2026
(Europe/London). Nothing was typed into the live form.

Contest close: 24 Nov 2026, 23:59 UTC. The form intro says the latest valid,
timely submission per project counts. License, build/test instructions and
documentation belong in the README. Registration code and contact email must
match. All dates are UTC.

After a successful submit, the form's confirmation copy is: "Received —
validation pending. A receipt is not acceptance. Contact hello@fe-lang.org if
you do not receive confirmation."

The personal link and codes from the 15 Nov registration email were not opened
or copied into this draft; SUBMISSION.md only notes that they are expected at
batchandledger@mail.grokbot.com.

## Form access: sign-in and edits

- **Google sign-in is not required to view or fill the public viewform.** An
  anonymous fetch returned all 12 questions. There is an optional "Sign in to
  Google to save your progress" link in the footer; it is not a sign-in wall.
  The contact email is a typed field (with email validation), not a
  Google-collected identity, so a Google account is not required to submit.
- **Post-submit editing is not indicated.** This draft did not submit a probe
  response, so a confirmation page was not clicked. The loaded form has no
  "Edit your response" copy. Its confirmation settings look like "submit
  another response" is on (consistent with "the latest valid, timely
  submission per project counts") and do not look like Google-linked
  edit-after-submit, which usually needs a sign-in or collected email. Treat
  a submitted answer as not editable; if something is wrong, submit again
  before the deadline and let the later one count. Re-check the confirmation
  page if and when Ali approves an actual submit.

## Answers

Every field on the form is required. Entry IDs below are from the public
form's `FB_PUBLIC_LOAD_DATA_` blob, for Ali's reference only.

### 1. Project ID
- Short text, max 500.
- **Answer:** `[TO_BE_FILLED from the registration email — not opened or copied into this draft]`

### 2. Private submission code
- Short text, max 500. SUBMISSION.md says to use the personal link from the
  registration email; this is the matching code field.
- **Answer:** `[TO_BE_FILLED from the registration email — not opened or copied into this draft]`

### 3. Registered contact email
- Short text, validated as an email address.
- **Answer (confirm it is exactly the address used on 15 Nov):** `batchandledger@mail.grokbot.com`
- Source: SUBMISSION.md records that inbox as the one that will receive the
  project ID and private submission link.

### 4. Final project name
- Short text, max 500.
- **Answer:** `lmsr-fe`

### 5. One-sentence pitch
- Paragraph, max 2000. Taken from the README pitch.
- **Answer:**

  A logarithmic market scoring rule (LMSR) prediction-market maker written in
  Fe: a reusable WAD fixed-point exp/ln library, an N-outcome LMSR whose
  rounding never lets the market maker lose money to dust, and a minimal
  on-chain market contract built on it.

### 6. Public GitHub repository URL
- Short text, max 500.
- **Answer:** `https://github.com/halfabillion/lmsr-fe`
- Note: that URL is already configured as `origin` on the local repo, and an
  unauthenticated `git ls-remote` on 18 Nov 2026 showed `master` at
  `45375df0ae365c3b273f8d2d94900cf9d540f09e` (the HEAD before this local
  package pass). This draft does not create, retitle, or push to that repo.
  Any later local commit must be pushed only with Ali's OK, and the form
  should be sent only after that SHA is visible on GitHub.

### 7. Full 40-character commit SHA
- Short text, max 500.
- **Answer:** `[TO_BE_FILLED: 40-character SHA of the commit Ali approves to push as GitHub master]`
- After the local package pass that added this draft, the local SHA will be
  in `git log -1 --format=%H` on `master`. Do not paste a SHA that exists
  only locally.

### 8. Exact Fe toolchain version
- Short text, max 500.
- **Answer:** `fe 26.5.0 (3dab95f)`
- Matches `fe --version` and the README / `fe.toml` instructions.

### 9. Fe-specific technical highlight
- Paragraph, max 2000. Adapted from the README "Fe highlight" section.
- **Answer:**

  Const generics and fixed-size arrays let one N-outcome LMSR serve any
  market size, while the contract keeps a single storage layout (capacity 8)
  and trades only n live outcomes. Fe's effect system makes each message
  handler declare exactly which storage fields and capabilities it touches:
  Price and QuoteBuy cannot write storage or send ETH, and the type checker
  enforces that. The math is unsigned-only: log-sum-exp with a max shift
  means exp is only ever called on non-positive arguments and ln only on
  arguments >= 1, all on Fe std's 512-bit mul_div.

### 10. Demo link or reproducible demo instructions
- Paragraph, max 2000.
- **Answer:**

  There is no hosted demo URL. From the repo, with Fe 26.5.0 and Foundry:
  run `scripts/demo.sh`. It compiles the Fe Market, starts a local anvil
  chain, and drives two markets with cast — a 3-outcome market through buy,
  overpay refund, sell, resolve, redeem and sweep, and a 2-outcome market
  whose resolve-by deadline has passed through cancel and refund. Sample
  output is in `scripts/demo-output.txt`. Automated tests are `fe test`
  (90 tests). Build and test instructions are in the README.

### 11. Pre-existing work, reused code and AI assistance (write None if none)
- Paragraph, max 2000. Taken from the README Declaration. Do not write
  "None".
- **Answer:**

  Pre-existing work: None of the LMSR or math is pre-existing. The
  repository started from the official fe-lang/builders-challenge-starter
  (vault example removed). All LMSR and math code was written during the
  contest window (from 15 Nov 2026). Third-party code: Fe std
  (core::num::mul_div, mul_div_ceil, isqrt, std::evm). The CI workflow and
  LICENSE come from the starter (Apache-2.0). AI assistance: Yes. AI coding
  assistants were used to write and test the code and docs, under the
  author's direction.

### 12. I confirm: public repository, OSI-approved license, manifest,
build/test instructions, automated tests and README at the submitted commit.
- Required checkbox, single option: `Confirmed`.
- **Answer:** check `Confirmed` only after the SHA in field 7 is actually
  visible on the public GitHub URL, the tree at that SHA has the Apache-2.0
  LICENSE (OSI-approved), `fe.toml`, README build/test instructions, and
  `fe test` (90 tests) is green. Do not check it against a local-only commit.

## What is still waiting on Ali

- OK to push any new local commits to `github.com/halfabillion/lmsr-fe`
  (do not push without that OK).
- Project ID and private submission code from the registration email.
- Confirm the registered contact email.
- OK to submit this form (this draft must not be sent automatically).
- Optional later items from SUBMISSION.md, not required by the form: a
  screen-recorded demo; ERC-20 collateral is out of scope for this package.
