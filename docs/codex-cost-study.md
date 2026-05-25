# FocusGuard Codex Cost Study

Date: 2026-05-25

## Short Answer

FocusGuard currently uses the local Codex CLI, not a direct OpenAI API call.
The app does not hard-code a model. On this machine, Codex is configured to use:

- Model: `gpt-5.5`
- Reasoning effort: `high`
- Codex CLI version checked locally: `codex-cli 0.133.0`

The current app sends **zero screenshots** to Codex. It has an in-memory
`ScreenshotBuffer`, but real ScreenCaptureKit capture is not wired yet, and the
classifier is currently called with `screenshotPath: nil`.

The main cost risk today is not screenshots. It is frequency: while a focus
session is active, FocusGuard evaluates context every 6 seconds. If local rules
do not already decide the answer, it calls Codex every time.

For the default 25 minute session, that can be up to:

```text
25 minutes * 60 seconds / 6 seconds = 250 Codex calls
```

That is too frequent for a Codex-backed classifier.

## What Runs Today

The app samples local context first:

- foreground app
- bundle identifier
- active window title
- browser URL and title when available
- idle seconds
- capture state

Then it applies local rules. Codex is only called when:

- there is an active session
- the Mac is not idle for 90+ seconds
- no allow/block/conflict local rule decides the answer
- Codex preflight says the CLI is ready

The relevant flow is:

- `SessionStore.startSamplingLoop()` runs every 6 seconds.
- `SessionStore.evaluateCurrentContext()` checks idle state and local rules.
- If there is no local decision, it calls:

```swift
classifier.classify(
    promise: activeSession.promise,
    context: context,
    screenshotPath: nil
)
```

Because `screenshotPath` is always `nil`, the current implementation is
metadata-only.

## Which Model Is It Using?

FocusGuard invokes:

```text
/opt/homebrew/bin/codex exec --ephemeral ...
```

It does not pass `--model`, so Codex uses the default configured for the local
Codex CLI account/config.

On this machine, the local Codex config says:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
```

Important implication: if another user has a different Codex config, FocusGuard
may use a different model unless the app explicitly passes `--model`.

Implementation update: FocusGuard now passes an explicit classifier model instead
of inheriting the global Codex default. The default is `gpt-5.3-codex` with low
reasoning because it is supported by the local ChatGPT-backed Codex CLI. A direct
test of `gpt-5.4-nano` through this Codex CLI failed with: `model is not
supported when using Codex with a ChatGPT account`. If FocusGuard later adds a
direct OpenAI API classifier provider, `gpt-5.4-nano` is still the right economy
target for metadata classification.

OpenAI's Codex CLI docs say the model can be controlled from Codex, including
switching between models such as `GPT-5.4` and `GPT-5.3-Codex`.

Source:

- https://developers.openai.com/codex/cli

## Screenshot Count

Today:

```text
Screenshots captured by FocusGuard: 0
Screenshots sent to Codex: 0
```

Why:

- `ScreenshotBuffer` exists and stores at most 8 frames / 12 MB by default.
- It excludes sensitive apps and identity-provider domains.
- But there is no ScreenCaptureKit capture pipeline yet.
- The classifier call passes `screenshotPath: nil`.

The README describes the intended v1 default as event-triggered screenshots
after suspected drift or ambiguous metadata. That is a product/design intent,
not the current implementation.

## Call Frequency

Worst case, with no local rule decision:

| Session length | Codex call interval | Max Codex calls |
| --- | ---: | ---: |
| 10 minutes | 6 seconds | 100 |
| 25 minutes | 6 seconds | 250 |
| 60 minutes | 6 seconds | 600 |
| 4 hours | 6 seconds | 2,400 |

Calls are reduced when local rules decide early. For example, if the user blocks
`x.com` or allows `developer.apple.com`, FocusGuard can decide locally and avoid
Codex for those contexts.

## Token Shape Per Call

The FocusGuard classifier prompt itself is small. A representative prompt is
about:

```text
~1,000 characters
~125-250 visible prompt tokens, depending on tokenizer
```

But Codex CLI is an agent, not a bare text-completion endpoint. A real call may
also include system instructions, tool definitions, local config, repository
instructions, and reasoning tokens. That means the visible FocusGuard prompt is
not the full billable token picture.

A practical planning range per classification call is:

| Scenario | Input tokens | Output/reasoning tokens | Notes |
| --- | ---: | ---: | --- |
| Lean | 1,000 | 200 | Best case for a tiny JSON decision |
| Expected | 2,000 | 500 | More realistic for Codex CLI overhead |
| Heavy | 5,000 | 1,000 | Possible with high reasoning / more context |

The only precise way to know is to instrument Codex usage from JSONL/session
usage events or add a direct Responses API classifier with explicit usage
logging.

## Cost Estimate With Current Local Model

As of 2026-05-25, OpenAI API pricing lists `gpt-5.5` standard short-context
pricing at:

- input: `$5.00 / 1M tokens`
- cached input: `$0.50 / 1M tokens`
- output: `$30.00 / 1M tokens`

Source:

- https://developers.openai.com/api/docs/pricing

Using non-cached input for conservative planning:

| Scenario | Cost per call | 25 min session, 250 calls | 1 hour, 600 calls |
| --- | ---: | ---: | ---: |
| Lean: 1k input + 200 output | ~$0.011 | ~$2.75 | ~$6.60 |
| Expected: 2k input + 500 output | ~$0.025 | ~$6.25 | ~$15.00 |
| Heavy: 5k input + 1k output | ~$0.055 | ~$13.75 | ~$33.00 |

This is why the README correctly warns that Codex calls are slow and token-heavy
for high-frequency polling.

## Codex Subscription / Credit View

If using Codex through a ChatGPT plan instead of direct API billing, OpenAI's
Codex rate card says token-based credit usage depends on input, cached input,
and output tokens.

For `GPT-5.5`, the current rate card lists:

- input: `125 credits / 1M tokens`
- cached input: `12.50 credits / 1M tokens`
- output: `750 credits / 1M tokens`

OpenAI also says average Codex usage is roughly `$100-$200/developer/month`,
with large variance depending on model, number of instances, automations, and
fast mode.

Source:

- https://help.openai.com/en/articles/20001106-codex-rate-card

FocusGuard's current 6-second loop is closer to an automation than normal
interactive developer use, so it should not assume the average developer monthly
number applies.

## What To Expect If Screenshots Are Enabled

Screenshots will increase input tokens because image inputs are billed as model
input. The exact token cost depends on how Codex processes the image, screenshot
resolution, detail level, and model behavior.

Expected direction:

- metadata-only classification: cheapest
- one screenshot attached to an ambiguous event: more expensive, but acceptable
  if rare
- screenshot every 6 seconds: not acceptable for cost or privacy

Recommended screenshot policy:

```text
Never screenshot on every 6 second sample.
Only screenshot after local metadata is ambiguous or suspicious.
Add a cooldown, such as 60-120 seconds per app/domain.
Keep screenshots explicit, visible, in memory only, and excluded for sensitive contexts.
```

## Recommended Budget Model

The cost-controlled design should target event-based Codex use:

| Design | Codex calls per 25 min | Expected cost on gpt-5.5 |
| --- | ---: | ---: |
| Current worst case | 250 | ~$6.25 expected |
| 60 second cooldown | up to 25 | ~$0.63 expected |
| 2 minute cooldown | up to 13 | ~$0.33 expected |
| Only suspected drift events | 3-10 | ~$0.08-$0.25 expected |

For a focus utility, the target should be:

```text
3-10 Codex calls per 25 minute session
0-2 screenshots per 25 minute session
```

That keeps Codex as a judgment boundary, not a polling loop.

## Practical Recommendations

1. Hard-code or expose the model used for classification.

   Implemented: the app now exposes classifier model settings and defaults to
   `gpt-5.3-codex` for Codex CLI compatibility instead of silently inheriting a
   user's expensive global Codex default.

2. Add a Codex cooldown.

   Implemented: the app now supports conservative, balanced, and aggressive AI
   cadence settings. Balanced mode avoids repeated calls for unchanged context
   and delays rapid changed-context calls.

3. Cache repeated context decisions.

   Implemented: the app now fingerprints promise, app, domain, title, and idle
   bucket, then reuses fresh AI decisions for unchanged context.

4. Keep local rules first.

   Corrections like "allow this" and "block this" are the cheapest path because
   they avoid future Codex calls entirely.

5. Make screenshots event-triggered only.

   Screenshot capture should stay opt-in and rare. Current code is safe because
   screenshots are not wired to Codex yet.

6. Add usage logging before shipping.

   Partially implemented: the app now tracks and displays per-session:

   - Codex calls attempted
   - Codex calls skipped by local rules
   - screenshots sent to Codex
   - model name
   - approximate tokens
   - estimated cost

## Bottom Line

FocusGuard is currently safe on screenshots because it sends none. The cost
problem is the 6-second Codex loop.

With the current local `gpt-5.5` / high-reasoning setup, a default 25 minute
session can plausibly cost several dollars if Codex is called on every sample.
The product should aim for event-triggered classification, not continuous
classification.
