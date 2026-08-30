# CI performance

A record of what's been tried to speed up this repo's pipeline (`.github/workflows/deploy.yml`), what
worked, what didn't, and what's still open. Complements the dated entries in
[`architecture-brief.md`](architecture-brief.md)'s Decisions section - this doc has the full numbers
and reasoning. `hobbs` has a parallel [`docs/CI_PERFORMANCE.md`](https://github.com/mojofunk5/hobbs/blob/master/docs/CI_PERFORMANCE.md)
- read that one too if a change here is being considered for there, since some of what's below was
learned by getting something wrong on that repo first.

All timings are wall-clock from real GitHub Actions runs (via `gh run view`) unless marked "local."

## Summary

| Stage | Before | After | Status |
| --- | --- | --- | --- |
| `subosito/flutter-action` (SDK install) | ~59-60s | ~13-21s | Confirmed, live |
| `flutter build web --release` | ~38s | ~26-27s | Confirmed, live |
| Docs-only commit | full pipeline | `changes` job only | Confirmed working end to end (real PR, `build`/`deploy` reported "skipped", PR still `MERGEABLE`) |

## What worked

### Flutter SDK caching
`subosito/flutter-action@v2` was reinstalling the entire SDK from scratch on every run. `cache: true`
caches it keyed by resolved version/channel - only the first run after a new stable release pays the
full cost again.

### Skipping the wasm dry-run compile
`flutter build web` runs an advisory wasm-compatibility check alongside the real JS compile by
default, even for a build that's never passed `--wasm` and was never going to ship it.
`--no-wasm-dry-run` turns that off. Verified before shipping, not assumed: a cold build with and
without the flag produced a byte-for-byte identical `main.dart.js` - the only diff was one inert
placeholder entry in `flutter_bootstrap.js`'s informational build-target list.

### Skipping CI for docs-only commits, safely
This repo's branch protection requires the `build` status check - the naive fix (a trigger-level
`paths-ignore` on the whole workflow) would have left that check permanently stuck "waiting to be
reported" and blocked merging, since a workflow that never triggers never posts any status at all.
Fixed with an always-running `changes` job whose output conditionally skips the expensive `build` job
via `if:`. A job skipped this way still reports "skipped", which GitHub counts as passing a required
check. Verified with a real docs-only PR ([#17](https://github.com/mojofunk5/hobbs-ui/pull/17)):
`build`/`deploy` both showed "skipped" and the PR still reported `MERGEABLE`.

The `changes` job's own docs-only detection went through two versions - see "What didn't work" for
why the first one (`dorny/paths-filter`) had to be replaced with a plain shell loop.

## What didn't work (and why)

### The first version of the docs-only-skip fix itself
A trigger-level `paths-ignore` (mirroring what looked like the working `hobbs` fix at the time) would
have broken merging entirely on this repo specifically, caught before shipping by checking this
repo's actual branch protection config
(`gh api repos/mojofunk5/hobbs-ui/branches/master/protection`) rather than assuming the same approach
would carry over safely. Branch protection is a GitHub feature offered free only on *public* repos -
`hobbs-ui` is public and has had `build` required since branch protection was added (see
`architecture-brief.md`'s 2026-08-29 entry) - a private repo wouldn't have this failure mode at all,
but also wouldn't have free branch protection to lose.

### `dorny/paths-filter`'s `predicate-quantifier: every`, take two
Used it here too, with the same wrong assumption as `hobbs` (see that repo's `docs/CI_PERFORMANCE.md`
for the full story): the option checks "does every declared *pattern* have at least one matching
file", not "does every changed *file* match a pattern". With filters `['**/*.md', 'docs/**']`, a
single changed doc file satisfies both patterns on its own, so a commit that also touched real code
alongside one doc file would have been wrongly classified docs-only and had its `build`/`deploy`
silently skipped. No PR here happened to combine docs and code changes since this mechanism was
introduced, so this never caused visible harm in practice - checked every run since (`gh run list`,
cross-referencing each `build` job's conclusion against that commit's actual file list) to confirm
that, rather than assume it. Fixed the same way as `hobbs`: a plain shell loop over
`git diff --name-only`, checking each changed file individually - verified locally against five cases
before shipping.

## Open opportunities

### Nothing else obvious identified yet
`flutter analyze` (~9s) and `flutter test` (~19-20s) haven't been investigated for further headroom -
both already small, not pursued given the size, but not measured for any real remaining slack either.
`dart2js` compilation itself (the bulk of `flutter build web --release`'s remaining ~26-27s) doesn't
have a documented, supported cross-run caching mechanism the way Gradle does - tested empirically
(cold build vs. warm `.dart_tool`/`build` directories, identical source both times) and found only a
~10% difference, not something worth building CI caching infrastructure around.

### Gradle build/configuration caching - `hobbs`-side, not this repo
Andy's specifically interested in this for the backend's compile/codegen overhead
(`generateJooq`/`compileJava`/`compileTestJava`, ~10s combined). Tracked in `hobbs`'s own
`docs/CI_PERFORMANCE.md` - no Gradle build here, so nothing to port across, but noting the connection
since both repos' CI docs cross-reference each other.
