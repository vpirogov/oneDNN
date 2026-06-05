# oneDNN Copilot Instructions

These instructions help a coding agent work productively in this repository.
**Trust them first** and only fall back to broad searching/exploration when the
information here is incomplete or proven wrong by the current state of the tree.

## 1. What this repository is

oneDNN (oneAPI Deep Neural Network Library) is a large, performance‑oriented
**C++11** library of deep‑learning building blocks (convolution, matmul, RNN,
normalization, attention/SDPA, etc.) for CPU and GPU. It is built with **CMake**
and uses just‑in‑time (JIT) code generation on x64. The codebase is large
(~70 MB of source under `src/`, `tests/`, `examples/`); full rebuilds are slow,
so prefer **incremental builds** and **targeted tests**.

Public API headers live in `include/oneapi/dnnl/`. Most contributions touch
`src/` (implementations) and `tests/` (gtests and benchdnn).

## 2. Repository layout (top level)

- `src/` — library sources.
  - `src/common/` — engine‑agnostic logic, primitive descriptors (`*_pd.hpp`),
    dispatch, utilities (`IMPLICATION`, `one_of`, `everyone_is`, etc.).
  - `src/cpu/` — CPU implementations. `src/cpu/x64/` holds Xbyak/JIT kernels
    (the bulk of x64 compile time), plus `aarch64/`, generic refs.
  - `src/gpu/` — GPU implementations (`intel/`, `nvidia/`, `amd/`, `generic/`).
  - `src/graph/` — graph API component (built with `ONEDNN_BUILD_GRAPH=ON`).
  - `src/xpu/` — shared CPU/GPU runtime glue (OpenCL/SYCL).
- `tests/` — `gtests/` (functional unit tests), `benchdnn/` (correctness +
  performance harness, see `tests/benchdnn/doc/`), plus `tests/other`.
- `examples/` — runnable API examples (built when `DNNL_BUILD_EXAMPLES=ON`).
- `include/` — public headers (`oneapi/dnnl/`).
- `doc/` — Doxygen/Sphinx docs. Build/option references live in `doc/build/`.
- `cmake/` — CMake helper modules and toolchain logic.
- `scripts/` — maintenance scripts (`fix_header_guards.py`,
  `generate_dnnl_debug.py`, `generate_format_tags.py`, `verbose_converter/`).
- `.github/` — CI workflows (`workflows/`) and automation (`automation/`).

Key root files: `CONTRIBUTING.md`, `CODING_STANDARDS.md`, `README.md`,
`.clang-format`, `.clang-tidy`, `.flake8`, `pyproject.toml`, `CMakeLists.txt`.

## 3. Build (validated)

The default toolchain available in the agent environment is GCC 13 / Clang
(18), CMake 3.31, Ninja, Python 3.12, 4 CPUs. CMake **3.13+** and a C++11
compiler are the only hard requirements. The most reliable, dependency‑light
configuration is **CPU‑only with the OpenMP runtime and no GPU**:

```sh
cmake -Bbuild -S. -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DDNNL_CPU_RUNTIME=OMP \
  -DDNNL_GPU_RUNTIME=NONE \
  -DONEDNN_BUILD_GRAPH=ON \
  -DDNNL_BUILD_TESTS=ON \
  -DDNNL_BUILD_EXAMPLES=ON
cmake --build build -j$(nproc)
```

Validated facts (do not re‑discover unless they fail):
- Configure takes only a few seconds. **A full build of the above
  configuration takes ~25–30 minutes on 4 cores** (1277 targets). Most of the
  time is x64 JIT/GEMM kernels under `src/cpu/x64/`.
- The build directory is `build/` and is **git‑ignored** (`/build*`). Keep all
  build artifacts there.
- Doxygen/Doxyrest/Sphinx are optional and missing by default — docs simply
  do not build; this is expected and not an error.

To minimize build time while iterating:
- Build only the library target: `cmake --build build -j$(nproc) --target dnnl`.
- Build a single test binary instead of everything, e.g.
  `cmake --build build -j$(nproc) --target test_sum`.
- Shrink scope at configure time with `-DDNNL_BUILD_TESTS=OFF`,
  `-DDNNL_BUILD_EXAMPLES=OFF`, or `-DONEDNN_TEST_SET=SMOKE` (see testing).

GPU/SYCL builds (`DNNL_GPU_RUNTIME=OCL|SYCL`, DPC++ compiler) require extra
SDKs that are typically **not** present; do not attempt them unless the task
specifically needs GPU and the tooling is available.

## 4. Test (validated)

Tests are driven by **CTest** from the build directory:

```sh
cd build
ctest -N                 # list available tests (235 with the config above)
ctest -j$(nproc)         # run the full enabled set (slow)
ctest -R test_sum --output-on-failure   # run a subset by name regex
```

- A single gtest (e.g. `test_sum`) builds quickly and passes in ~2 s once the
  library is built — use targeted `ctest -R <regex>` for fast feedback.
- Test coverage is controlled by the CMake option **`ONEDNN_TEST_SET`**
  (`SMOKE`, **`CI`** default, `NIGHTLY`, plus modifiers). Use `SMOKE` for the
  fastest signal, `CI` for normal validation. `NIGHTLY` is advised before large
  changes but is expensive.
- benchdnn (`build/tests/benchdnn/benchdnn`) is the harness for correctness +
  performance of individual primitives; see
  `tests/benchdnn/doc/benchdnn_general_info.md`.

## 5. Linting / formatting — required to pass CI

CI (`.github/workflows/pr-linter.yml`) enforces all of the following. Run the
relevant ones locally before finishing.

### C/C++ formatting (clang-format) — **mandatory**
The repo pins **clang-format-18**. Format every C/C++ file you touch:
```sh
clang-format-18 -style=file -i <file.cpp/.hpp/.c/.h/.cl>
```
Or check only changed files against a base commit (mirrors CI):
```sh
.github/automation/clang-format.sh <base_sha>
```
Applies to extensions: `c h cpp hpp cxx hxx cl`. Using a clang-format version
other than 18 can produce spurious diffs.

### Header guards — **mandatory** for new/renamed headers
```sh
./scripts/fix_header_guards.py -v <changed-header-files>
```

### Commit messages — **mandatory** (checked by CI)
Follow the format `<scope>:[scope: ..] <short description>`, imperative mood,
subject ≤ 50 (max 72) chars, body wrapped at 72.
- Top‑level scopes: `build`, `api`, `doc`, `tests`, `common`, `cpu`, `gpu`,
  `graph`.
- Example: `common: verbose: fix crash when prim_iface_t is empty`.
Checked by `.github/automation/commit-msg-check.py`.

### License header — **mandatory** for new files
Every source file needs an Apache‑2.0 SPDX copyright header (year + holder).
Copy the header from a neighboring file of the same language; CI verifies this
via skywalking‑eyes (`.github/.licenserc.yml`).

### Python (only if you change `.py`/`.pyi`/`.py.in` files)
Tools are configured by `pyproject.toml` and `.flake8` but are **not installed
by default** — install them first:
```sh
pip install black isort flake8 mypy pyright
black . && isort . && flake8 && mypy && pyright
```
`line-length` is 80; `isort` uses the `black` profile. Only `.github`,
`scripts`, and `doc` are type‑checked.

### clang-tidy (optional, slow)
`.clang-tidy` lists the enforced checks (naming, readability, performance,
modernize, bugprone). A full clang-tidy run needs a compile DB
(`-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`) and is expensive; rely on it only when
your change relates to a specific check.

## 6. Coding conventions (see `CODING_STANDARDS.md`)

- Match the style of surrounding code; code design takes priority over style.
- Name magic constants; avoid `using namespace` in headers; avoid code
  duplication; use `src`/`dst` (not `input`/`output`); declare variables in the
  innermost scope; prefer the `utils` helpers (`IMPLICATION`, `one_of`,
  `everyone_is`).
- Xbyak JIT code: use `Xbyak::Label` variables for labels, never `char[]`.
- Primitive implementations are registered in `*_list.cpp` files (e.g.
  `src/cpu/cpu_convolution_list.cpp`); a new implementation must be added to the
  relevant list to be dispatched.

## 7. Workflow expectations for changes

1. Configure once with the CPU/OMP command in §3 (reuse the `build/` dir for
   fast incremental rebuilds).
2. Make the smallest correct change; add an implementation to its `*_list.cpp`
   if you add a new primitive impl.
3. Rebuild the minimal target and run a **targeted** `ctest -R` for the area you
   touched. Add/extend tests when changing behavior (gtests for functional,
   benchdnn for performance‑sensitive primitives).
4. `clang-format-18` all changed C/C++ files; fix header guards / license header
   on new files; keep commit messages in the required format.
5. Note: this is a mirror; upstream is `uxlfoundation/oneDNN`. The product
   branches (`main`/`master`, `rls-*`, `mnt-*`) maintain **linear history** —
   prefer focused, self‑contained commits.

## 8. Known environment gotchas

- Full first build is long (~25–30 min). Budget for it; do not assume a hang.
- Python lint tools, `castxml` (used by the `pr-format-tags` CI job), and
  Doxygen/SYCL/OpenCL SDKs are typically absent — install or skip as needed and
  document any workaround.
- If `clang-format` (unversioned) differs from 18, format diffs may appear that
  CI would not flag; use `clang-format-18` explicitly.
