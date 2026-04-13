OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text : {
    *(.text._start)
    *(.text)
  }
  .data : {
    *(.rodata*)
    *(.data*)
    *(.sdata*)
  }
  .bss : {
    *(.bss*)
    *(.sbss*)
  }
  _end = .;
}
