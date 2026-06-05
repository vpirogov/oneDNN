# GitHub Copilot Instructions for oneDNN

These instructions guide GitHub Copilot when reviewing pull requests for the
oneDNN project. They are derived from the project's governance documents:
[CONTRIBUTING.md](../CONTRIBUTING.md), [CODING_STANDARDS.md](../CODING_STANDARDS.md),
[MAINTAINERS.md](../MAINTAINERS.md), [SECURITY.md](../SECURITY.md), and the
[pull request template](pull_request_template.md).

The goal is to produce review feedback that helps contributors meet oneDNN's
bar for promotion to product branches: changes must be **tested**, **documented**,
**portable**, and **performant**. Prioritize feedback that flags missing tests
and missing documentation, since these are the most common gaps that block
promotion.

## Review priorities

When reviewing a change, evaluate it against the following, in order:

1. **Documentation impact** — does this change require documentation updates?
2. **Test coverage** — does this change require new or updated tests?
3. **Correctness, portability, and security**.
4. **Coding standards and style**.

Always make documentation and test gaps explicit. If a change adds, removes, or
modifies observable behavior and the PR does not touch documentation or tests,
call this out as a required follow-up rather than a minor nit.

## Flag changes that require documentation updates

Recommend documentation changes whenever a PR does any of the following. Point
to the specific document(s) that should be updated.

- **Public API changes**: any change under [include/](../include) (new or modified
  functions, enums, types, structs, macros). Require updated Doxygen inline
  comments in the public headers and corresponding updates to the developer
  guide under [doc/](../doc).
- **New primitive or new primitive feature**: require a corresponding developer
  guide page or update under [doc/primitives/](../doc/primitives) and, where
  relevant, [doc/usage_models/](../doc/usage_models) and example code under
  [examples/](../examples). New primitives and API modifications also require an
  approved RFC (see below).
- **Behavioral or semantic changes**: changes to defaults, supported data types,
  supported formats/tags, propagation kinds, attributes, post-ops, or scratchpad
  behavior must be reflected in the developer guide and the relevant benchdnn
  driver documentation under [tests/benchdnn/doc/](../tests/benchdnn/doc).
- **New benchdnn knobs, options, or driver behavior**: require updates to the
  matching files under [tests/benchdnn/doc/](../tests/benchdnn/doc).
- **New build options or build-time behavior**: require updates to the build
  documentation under [doc/build/](../doc/build).
- **Naming**: new tensors, variables, or formulas in documentation must follow
  [doc/naming_conventions.md](../doc/naming_conventions.md) (for example, use
  `src`/`dst` rather than `input`/`output`).
- **Verbose output changes**: any change to verbose/log formatting should be
  documented and kept consistent with existing conventions.

If a change is user-visible but the PR contains no documentation edits, state
clearly that documentation updates appear to be missing and name the expected
location.

## Flag changes that require additional tests

oneDNN uses **gtests** ([tests/gtests/](../tests/gtests)) for lightweight
functional testing and **benchdnn** ([tests/benchdnn/](../tests/benchdnn)) for
combined performance and functional testing. Recommend test additions or updates
whenever a PR does any of the following.

- **Bug fix**: require a regression test that fails without the fix and passes
  with it. A bug fix without a new or updated test should be flagged.
- **New feature, primitive, data type, format, or attribute**: require new
  functional coverage (gtests and/or benchdnn) exercising the new behavior,
  including edge cases.
- **Modified existing behavior**: verify that existing tests still cover the
  changed code path; if not, request that coverage be extended to validate the
  change.
- **New public API**: require tests that exercise the new entry points, including
  error/validation paths.
- **Performance optimizations**: request supporting performance data and confirm
  that functional correctness remains covered.

When recommending tests, prefer pointing to the existing test that should be
extended over asking for entirely new infrastructure. If a code path is not
covered by any existing test, say so explicitly.

## Process and contribution requirements

- **RFC requirement**: new primitives, library architecture changes, and public
  API modifications require an approved RFC before implementation. If a PR
  introduces such changes without referencing an approved RFC, flag it.
- **Performance justification**: new functionality should demonstrate material,
  workload-level performance benefit and broad applicability. Ask for supporting
  data when it is missing.
- **Commit hygiene**: commit subjects should use the imperative mood, fit within
  50 (at most 72) characters, and follow the `<scope>:[scope: ..] <short description>`
  format (for example, `common: verbose: fix crash when prim_iface_t is empty`).
  Commit bodies should wrap at 72 characters. Unrelated changes (for example,
  cleanup vs. a fix) should be split into separate, self-contained commits.
- **Linear history**: the project maintains linear history; flag merge commits.

## Coding standards and style

Follow [CODING_STANDARDS.md](../CODING_STANDARDS.md). The general principle is to
match the style of surrounding code. Note that style is secondary to overall code
design — do not block on style when the design is sound.

- C/C++ formatting is enforced by `clang-format` (`.clang-format`); flag obvious
  formatting deviations but assume the contributor will run the formatter.
- Common issues to flag: magic numbers that should be named constants,
  `using namespace` in header files, avoidable code duplication, variables not
  declared in the innermost reasonable scope, and `input`/`output` naming where
  `src`/`dst` is expected.
- Prefer readability helpers where idiomatic (`IMPLICATION`, `one_of`,
  `everyone_is`).
- For Xbyak JIT code, use `Xbyak::Label` variables rather than `char[]` label
  names.
- Python code is formatted and checked with `black`, `isort`, `flake8`, `mypy`,
  and `pyright`; flag violations in changed Python files.
- Note `clang-tidy` violations, since these are enforced and not subject to the
  general "match surrounding code" exception.

## Portability

oneDNN supports multiple operating systems, CPU and GPU architectures, compilers,
and runtimes. Flag code that is likely non-portable: platform-, compiler-, or
architecture-specific assumptions that are not properly guarded, reliance on
undefined or implementation-defined behavior, and changes that may break builds
on a supported configuration.

## Security

- Be vigilant for memory safety issues (buffer overflows, out-of-bounds access,
  use-after-free), integer overflow in size/offset computations, and unchecked
  inputs at API boundaries.
- Do not request that security vulnerabilities be disclosed in public PR
  comments. If a change appears security-sensitive, note it generally and refer
  to the private reporting process in [SECURITY.md](../SECURITY.md).

## Tone and feedback style

- Be specific and actionable. Reference the exact file, location, and the
  document or test that should be updated.
- Clearly distinguish blocking concerns (missing tests, missing documentation,
  missing RFC, correctness, portability, security) from minor suggestions.
- When tests or documentation are missing, state it plainly rather than implying
  it — these are the highest-value review outcomes for this project.
