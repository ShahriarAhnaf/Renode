### Description

Renode's `tlib` ARM translation backend treats the Thumb-2 **MOV (register) T3** encoding with `Rm == 13` (SP) as **UNDEFINED**, raising a UsageFault (UNDEFINSTR). The ARMv7-M Architecture Reference Manual (DDI 0403E, §A7.7.77) marks this encoding as **UNPREDICTABLE**, not UNDEFINED, and all real Cortex-M4 silicon (nRF52840, STM32F4xx) executes it as a simple register move.

This blocks simulation of the **Nordic nRF5 SoftDevice S140 v7.x**, which uses `MOV.W R0, SP` (encoding `EA4F 000D`) in its SVC call dispatcher. The SoftDevice is a precompiled binary blob and cannot be recompiled.

The affected encoding:

```
EA4F 000D
  hw1 = 0xEA4F -> data-processing (shifted register), op=0010 (ORR), Rn=0xF (=> MOV)
  hw2 = 0x000D -> Rd=R0, imm3=0, imm2=0, type=LSL, Rm=R13 (SP)
  Result: MOV.W R0, SP  (no shift)
```

The same issue applies to the **ORR (register) T2** encoding (§A7.7.92), which shares the same decoder path.

### Expected behaviour

`MOV.W R0, SP` (`EA4F 000D`) should execute as a simple register move, copying SP into R0. Instead, Renode raises a UsageFault with `UFSR.UNDEFINSTR` set.

### How to reproduce?

Reproduction repository: **[ShahriarAhnaf/Renode](https://github.com/ShahriarAhnaf/Renode)**

Two branches are provided:

- **[`failing_case`](https://github.com/ShahriarAhnaf/Renode/tree/failing_case)** — adds a Robot Framework test that exercises the `EA4F 000D` encoding on a Cortex-M4. The test **fails** because tlib raises UsageFault.
- **[`passing_case`](https://github.com/ShahriarAhnaf/Renode/tree/passing_case)** — includes the tlib fix (one-line decoder condition change). The same test **passes**.

The test is at `tests/unit-tests/tlib/arm/thumb2-mov-sp-unpredictable.robot` and is registered in `tests/tests.yaml`.

To run:

```bash
git checkout failing_case
git submodule update --init --recursive
rm -rf src/Infrastructure/src/Emulator/Cores/obj/Release/arm-m
./build.sh --host-arch aarch64   # or i386 on x86_64
./renode-test tests/unit-tests/tlib/arm/thumb2-mov-sp-unpredictable.robot
# Result: FAILS — R0 = 0xDEADDEAD (UsageFault handler ran)

git checkout passing_case
git submodule update --init --recursive
rm -rf src/Infrastructure/src/Emulator/Cores/obj/Release/arm-m
./build.sh --host-arch aarch64
./renode-test tests/unit-tests/tlib/arm/thumb2-mov-sp-unpredictable.robot
# Result: PASSES — R0 = 0x20010000 (SP value, no fault)
```

### The fix

In `tlib/arch/arm/translate.c`, the Thumb-2 data-processing (shifted register) decoder for `op == 2` (ORR/MOV) rejects `Rm == 0xd` (SP):

```c
// Before (line 11679):
if(op0 == 0 && rm != 0xd && rm != 0xf) {

// After:
if(op0 == 0 && rm != 0xf) {
```

Removing `rm != 0xd` allows SP as a source register, matching hardware behaviour. `Rm == 0xf` (PC) remains rejected.

### Environment

- **OS**: macOS 26.3.1 (arm64)
- **Renode version**: master at commit `2dc81edf`

### Additional information

The SoftDevice S140 v7.x uses this encoding at two addresses:

| Address    | Encoding    | Instruction     | Context                   |
|------------|-------------|-----------------|---------------------------|
| `0x00B250` | `EA4F 000D` | `MOV.W R0, SP`  | SD early init SVC handler |
| `0x01304C` | `EA4F 000D` | `MOV.W R0, SP`  | SD main SVC dispatcher    |

The encoding is likely produced by `arm-none-eabi-gcc` when optimizing `__asm__ volatile("mov %0, sp" : "=r"(result))`.

Related upstream issues:
- https://github.com/renode/renode/issues/158
- https://github.com/renode/renode/issues/279
- https://github.com/renode/renode/issues/499

### Do you plan to address this issue and file a PR?

Yes. The fix is a one-line change in `tlib/arch/arm/translate.c`. The `passing_case` branch in the reproduction repo contains the complete fix with a passing test. I plan to file PRs against both `tlib` and `renode-infrastructure` once the issue is acknowledged.
