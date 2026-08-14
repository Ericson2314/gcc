# UR-STUBS — every stub this branch has installed to make a link succeed

**This is a WORK QUEUE for the correctness pass, not documentation of a
finished state.** Everything listed here links and does not work.

The coordinator suspended PRINCIPLES §2a's ban on stubs *for link-level fixes
only*, on two conditions: a stub must **abort by name** rather than return a
plausible value, and every stub must be recorded **here**. Both conditions are
met by every entry below; an entry that ever stops meeting them is a bug.

**Why abort and not a default.** The banned shape is a stub that returns the
primary back end's answer. It compiles, it links, it produces wrong code, and
it leaves nothing to grep for — this project has lost multiple sessions to
exactly that (a null `ix86_cost`, a wrong CFA offset, `Pmode` reading the
primary's *unconfigured* default). An abort naming itself costs one ICE and
zero archaeology.

## The stubs

| symbol | file | back ends that reach it | what it should be |
|---|---|---|---|
| `only_leaf_regs_used` | `gcc/final.cc` | **sparc, ia64** — the only two defining `LEAF_REGISTERS` | `LEAF_REGISTERS` is a per-back-end string constant indexed by regno. It wants the cdata treatment (a per-base table plus a runtime select), exactly like the other register vocabularies. Until then this `internal_error`s. |

**Reachability of the one stub above is bounded and was checked, not assumed:**
the shared caller `rest_of_handle_check_leaf_regs` (`gcc/function.cc:6490`) is
itself inside `#ifdef LEAF_REGISTERS` and is compiled out alongside the real
definition, so the only surviving callers are inside `sparc.cc`'s and
`ia64.cc`'s own objects. The abort therefore fires when sparc or ia64 is
*selected*, and never for the other 46 back ends.

## Deliberately NOT stubbed — fixed for real

Recorded here so nobody later "discovers" these and adds them to the queue:

- `immed_double_const` (`emit-rtl.cc`) — guard deleted, body reads no target
  macro. Real definition, not a stub.
- `merge_dllimport_decl_attributes` / `handle_dll_attribute` (`attribs.cc`) —
  guard deleted. Whether a back end *uses* them is still that back end's own
  decision, made in its own `targetm`.
- `unspec_strings` / `unspecv_strings` and their lengths (`genenums.cc`) — the
  empty table with length 0 is the back end's **own** answer (its md declares
  no such enum, so it has no names), not a borrowed one. No consumer can index
  it, because every consumer's bound is the length.

## Known leaks left in place, named rather than papered over

- Two `#if TARGET_WIN32_TLS` blocks inside `attribs.cc`'s
  `handle_dll_attribute` are still read with the **primary's** headers. Same
  defect one level down; not on any currently-linking path.
- `ia64` lists `ia64-c.o` in `c_target_objs` with no tmake fragment claiming a
  rule for it, exactly as `v850` did. It does not break the link today only
  because nothing references `ia64-c.cc`'s symbols. `gen-multi-target-md.awk`
  now emits a `$(warning)` for this class rather than dropping it silently.
