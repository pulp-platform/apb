# APB

This is the implementation of the AMBA APB protocol, version 2, developed as part of the PULP
platform at ETH Zurich.

Maintainer: Andreas Kurth <akurth@iis.ee.ethz.ch>

## Overview

### Interfaces

|           Name            |                     Description                                   |
|---------------------------|-------------------------------------------------------------------|
| `APB`                     | APB2 interface with 32-bit address and data channels              |
| `APB_DV`                  | Clocked variant of `APB` for design verification                  |

### Leaf Modules

|           Name            |                     Description                                   |
|---------------------------|-------------------------------------------------------------------|
| `apb_ro_regs`             | Registers with read-only APB interface                            |
| `apb_rw_regs`             | Registers with read- and writable via APB                         |

### Intermediary Modules

|           Name            |                     Description                                   |
|---------------------------|-------------------------------------------------------------------|
| `apb_bus`                 | APB bus with single master and multiple slave interfaces          |

### Verification and Simulation

|           Name            |                     Description                                   |
|---------------------------|-------------------------------------------------------------------|
| `apb_driver`              | APB driver (can act as either slave or master)                    |
