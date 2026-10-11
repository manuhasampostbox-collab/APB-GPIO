# APB GPIO Peripheral (Verilog)

A memory-mapped GPIO block built as an AMBA APB (Advanced Peripheral Bus)
slave — the kind of simple register-based peripheral you'd hang off an APB
bridge in an SoC.

## Register map
| Offset | Name       | Access | Description                                   |
|--------|------------|--------|------------------------------------------------|
| 0x0    | DATA_OUT   | R/W    | Output pin values                              |
| 0x4    | DATA_IN    | RO     | Live input pin values (`gpio_in`)              |
| 0x8    | DIR        | R/W    | Pin direction: 1 = output, 0 = input            |
| 0xC    | INT_STATUS | R/W1C  | Set on any input pin change; write 1 to clear   |

## Files
- `apb_gpio.v` — synthesizable RTL: APB slave + GPIO register block.
- `tb_apb_gpio.v` — self-checking testbench driving standard APB setup/access
  write and read transactions.

## Design notes
- Follows the standard two-phase APB protocol: a SETUP cycle (`PSEL=1`,
  `PENABLE=0`) followed by an ACCESS cycle (`PSEL=1`, `PENABLE=1`).
- `PREADY` is tied high (zero wait-state slave), matching simple register
  peripherals.
- `PSLVERR` is asserted on an illegal write (e.g. writing to the read-only
  `DATA_IN` register), so the bus master can detect a misbehaving driver.
- `INT_STATUS` is a classic write-1-to-clear interrupt-status register: it
  latches any edge on `gpio_in`, and software clears individual bits by
  writing a 1 to them.

## Test coverage
1. `DIR` register write + readback
2. `DATA_OUT` register write + readback, and that `gpio_out` reflects it
3. `DATA_IN` reflects the live `gpio_in` input pins
4. `INT_STATUS` latches an input change, and write-1-to-clear works
5. Writing to the read-only `DATA_IN` register correctly asserts `PSLVERR`

## Running the simulation
```bash
iverilog -g2012 -o sim apb_gpio.v tb_apb_gpio.v
vvp sim
```

### Example output
```
[PASS] DIR readback: got 0x000000f0
[PASS] DATA_OUT readback: got 0x000000a5
[PASS] gpio_out pin value: got 0x000000a5
[PASS] DATA_IN reflects input pins: got 0x000000c3
[PASS] INT_STATUS latched input change: got 0x000000c3
[PASS] INT_STATUS cleared after write-1-to-clear: got 0x00000000
[PASS] PSLVERR on illegal write to DATA_IN: got 0x00000001
--------------------------------------------------
APB GPIO test summary: 7 passed, 0 failed
--------------------------------------------------
RESULT: ALL TESTS PASSED
```
