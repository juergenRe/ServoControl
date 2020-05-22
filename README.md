# ServoControl
Created for Vivado 2019.1
Reusable IP for controlling servo motors using a PWM output signal. This component is designed to be integrated in a BD containing a Zynq processing device, thus data transfer is using AXI4 protocol using 3 registers.
The component is configurable:
- Nb of pwm channels 1 to 16
- resolution from 4 to 16 bits
- prescaler bits from 2 to 16 bits; prescaler works on all channels

Register description:
Register 1: (write-only) combined channel/value. channel: upper 4 bits; value: lower part according precision chosen
Register 2: (write-only) configuration and global on/off. Configuration in lower part, global on/off in bit31
Register 3: (read-only) status: bit 31 = '1' --> ready, oherwise wait
Register 4: unused

## Recreating the project
This should be done using the scripts in /proj subfolder:
- cd into <project folder>/proj
- `source ./create_project.tcl`

## Create recreation script
- cd into <project folder>/proj
- execute: `write_project_tcl -paths_relative_to . -origin_dir_override . -force create_project.tcl`

## create IP from it:
- cd into <project folder>/proj
- rename IP is necessary, also check top module and compile order at the end of the script
- execute: `source ./mkIP.tcl`
- commit changes in folders src, xgui and component.xml. Subfolder "project" might be deleted.
- recreate depending projects
- ipx::* is poorly documented; best choice is to use `help ipx::*` to get a list of commands and then call help for each command.

## Debugging with ILA at startup:
Ref: see UG908, Chapter 11, "Trigger at startup"

1. implement design and set triggers in ILA dashboard
2. cd to /proj folder
3. `run_hw_ila -file ila_trig.tas [get_hw_ilas hw_ila_1]`
4. open implemented design
5. `apply_hw_ila_trigger ila_trig.tas`
6. `write_bitstream -force trig_at_startup.bit`
7. reopen Hardware manager and select device (xc7c020)
8. select newly written bit file in properties window
i) reprogram device which should then trace immediately
