# Done

Plan docs move here from `docs/plans/` once every chunk they describe has merged - see
`docs/ai-working-agreement.md`'s rule 12 ("Closing Out a Plan Doc Is Part of the PR That Finishes
It") for exactly when and how. Mirrors the identical convention in the sibling `hobbs` repo.

A doc landing here still has a `Status:` line saying it's implemented, with links to the PR(s) that
did it - the file itself doesn't change shape or lose content, it just moves. `docs/plans/` (the
parent folder) becomes, by construction, the list of what's designed but not yet fully built.

The two plan docs that were already implemented before this convention existed
(`flight-entry-context-prefetch.md`, `split-create-flight-entry-screen.md`) were initially left in
`docs/plans/` rather than bulk-moved, to avoid a mechanical PR rewriting every cross-reference to
them at once. That bulk move (and the matching one in `hobbs`) happened on 2026-08-31, once every
cross-reference in this repo had been checked and fixed up in the same change - see `hobbs`'s
equivalent `docs/plans/done/README.md` for the same move applied there.
