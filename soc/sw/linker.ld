ENTRY(_start)

MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00010000, LENGTH = 8K
  DMEM (rwx) : ORIGIN = 0x00020000, LENGTH = 8K
}

SECTIONS
{
  .text : {
    KEEP(*(.text.start))
    *(.text*)
    *(.rodata*)
    *(.srodata*)
  } > IMEM

  .data : AT (LOADADDR(.text) + SIZEOF(.text)) {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)
    *(.sdata*)
    . = ALIGN(4);
    _edata = .;
  } > DMEM

  _sidata = LOADADDR(.data);

  .bss : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss*)
    *(.sbss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > DMEM

  . = ORIGIN(DMEM) + LENGTH(DMEM);
  _stack_top = .;
}
