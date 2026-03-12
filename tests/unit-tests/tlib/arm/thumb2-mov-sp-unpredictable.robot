*** Variables ***
# Minimal Cortex-M4 platform with NVIC, flash, and SRAM — matches nRF52840 core.
${PLATFORM}                         SEPARATOR=\n
...                                 """
...                                 flash: Memory.MappedMemory @ sysbus 0x0
...                                 ${SPACE*4}size: 0x40000
...                                 sram: Memory.MappedMemory @ sysbus 0x20000000
...                                 ${SPACE*4}size: 0x10000
...                                 cpu: CPU.CortexM @ sysbus
...                                 ${SPACE*4}cpuType: "cortex-m4"
...                                 ${SPACE*4}nvic: nvic
...                                 nvic: IRQControllers.NVIC @ sysbus 0xE000E000
...                                 ${SPACE*4}-> cpu@0
...                                 """

# MOV (register) T3 encoding — EA4F 000D decodes as MOV.W R0, SP.
# Per ARM DDI 0403E §A7.7.77 Rm==13 (SP) makes this UNPREDICTABLE,
# but all Cortex-M4 silicon executes it as a simple register move.
# This encoding appears in the Nordic nRF5 SoftDevice S140 SVC dispatcher.
${MOV_SP_ASSEMBLY}                  SEPARATOR=\n
...                                 """
...                                 .syntax unified
...                                 .thumb
...                                 Vector_Table:
...                                 .word 0x20010000
...                                 .word Reset_Handler+1
...                                 .word 0
...                                 .word 0
...                                 .word 0
...                                 .word 0
...                                 .word UsageFault_Handler+1
...                                 .align 8
...
...                                 Reset_Handler:
...                                 ldr r1, =0xE000ED24
...                                 ldr r2, [r1]
...                                 orr r2, r2, #0x40000
...                                 str r2, [r1]
...
...                                 ldr sp, =0x20010000
...                                 .inst.w 0xEA4F000D
...                                 str r0, [sp, #-4]!
...                                 b Done
...
...                                 UsageFault_Handler:
...                                 ldr r0, =0xDEADDEAD
...                                 str r0, [sp, #-4]!
...
...                                 Done:
...                                 wfi
...                                 """

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 cpu AssembleBlock 0x0 ${MOV_SP_ASSEMBLY}
    Execute Command                 cpu VectorTableOffset 0x0

*** Test Cases ***
Should Execute MOV.W R0 SP With T3 Encoding Without UsageFault
    [Documentation]                 MOV (register) T3 with Rm=SP (0xEA4F 0x000D) is UNPREDICTABLE per
    ...                             ARMv7-M ARM but must not raise UNDEFINED. Real Cortex-M4 silicon
    ...                             (nRF52840, STM32F4xx) executes it as a simple register move.
    ...                             This encoding is used by the Nordic nRF5 SoftDevice S140 v7.x
    ...                             SVC dispatcher and cannot be recompiled.
    Create Machine

    Execute Command                 emulation RunFor "0.001"

    # If the instruction executed correctly, R0 should contain the SP value
    # and the word below SP should hold that value (written by STR).
    # If it faulted, the UsageFault handler writes 0xDEADDEAD instead.
    ${val}=                         Execute Command  sysbus ReadDoubleWord 0x2000FFFC
    Should Not Contain              ${val}  0xDEADDEAD  MOV.W R0, SP (T3 encoding EA4F 000D) raised UsageFault — UNPREDICTABLE treated as UNDEFINED
    ${r0}=                          Execute Command  cpu GetRegisterUnsafe 0
    Should Be Equal As Numbers      ${r0}  0x20010000  R0 should contain the original SP value after MOV.W R0, SP
