# Ethernet Packet Modifier with AXI4

A VHDL project that modifies Ethernet packets on an AXI4-Stream interface by inserting a 4-byte VLAN field after the Source MAC Address. The design also exposes an AXI4-Lite slave interface for configuring the VLAN value and reading version information.

## Overview

The design is centered on `axi4_vlan_inserter` and includes:

- **AXI4-Stream input and output:** 64-bit `TDATA` buses, 8-bit `TKEEP`, `TVALID`/`TREADY` handshaking, and `TLAST` frame indication.
- **VLAN insertion:** uses a configurable 32-bit value from the VLAN register.
- **AXI4-Lite control:** register access for VLAN configuration and version read-back.
- **Finite-state machine:** `IDLE`, `COPY_HDR1`, `COPY_HDR2`, and `FORWARD_PAYLOAD` states manage header handling and forwarding.

## Register map

| Address | Register | Access | Description |
|---|---|---|---|
| `0x00` | `REG_VERSION` | Read-only | Version value, initialized to `0x00000100` |
| `0x04` | `reg_vlan_id` | Read/write | VLAN value; initialized to `0x00000001` |

AXI4-Lite data and address signals are 32-bit and 4-bit respectively in the documented interface. The design returns an OKAY response (`00`) for the implemented read/write operations.

## Design files

The project document identifies these VHDL sources:

- `axi4_vlan_inserter.vhd` — synthesizable design entity and behavioral architecture.
- `tb_axi4_vlan_inserter.vhd` — first simulation testbench.
- `tb2_axi4_vlan_inserter.vhd` — second simulation testbench.

Use the actual filenames in your source directory if they differ; the testbench source names above are based on the entities shown in the project document.

## Requirements

- AMD/Xilinx Vivado **or** ModelSim/QuestaSim
- VHDL simulation support

No software package installation steps are specified in the project document.

## Run simulation in Vivado

1. Open Vivado and create a new RTL project.
2. Add the design VHDL file and the desired testbench VHDL file.
3. Set the testbench entity as the simulation top. The project document specifies `tb2_axi4_vlan_inserter` for its second testbench.
4. Select **Run Simulation → Run Behavioral Simulation**.
5. Inspect the waveform and simulator messages.

The documented checks include:

- AXI4-Lite register write/read behavior and version read-back.
- VLAN value appearing in the output stream at the intended insertion point.
- AXI4-Stream handshaking and packet-end signaling.

For ModelSim/QuestaSim, create a VHDL project, compile the design before the testbench, set the selected testbench as the simulation top, and run the simulation. Exact commands and simulator scripts are not included in the source document.

## Testbench scenarios

The supplied testbench examples:

1. Apply reset and configure the VLAN register through AXI4-Lite.
2. Drive several 64-bit AXI4-Stream beats representing packet header and payload data.
3. Check that the configured VLAN value is present in the output data.
4. Mark the final stream beat using `TLAST`.

The examples use different VLAN values, including `0x12345678` and `0x00001000`.

## Interface notes

### AXI4-Stream

Input signals use the `s_axis_` prefix; output signals use `m_axis_`. The interface includes:

- `tdata[63:0]` — data beat
- `tkeep[7:0]` — valid-byte indicators
- `tvalid` / `tready` — transfer handshake
- `tlast` — final beat of a frame

### AXI4-Lite

The control interface includes the standard write-address, write-data, write-response, read-address, and read-data channels. The documented register addresses are `0x00` and `0x04`.

## Implementation and verification note

This README describes the design and simulation flow documented with the project. Before using the RTL in a hardware system, review and verify byte ordering, VLAN-tag placement, `TKEEP` handling, `TLAST` propagation, and behavior under output backpressure. The source document provides example testbenches and expected checks, but does not establish complete protocol compliance or hardware validation.

## Project background

Project: **VHDL Design of Ethernet Packet Modifier with AXI4-Stream and AXI4-Lite Interface**  
Organization listed in project document: VVDN Technologies  
Date listed: 14 July 2025
