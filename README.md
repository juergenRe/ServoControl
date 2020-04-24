# Empty project template
Created for Vivado 2019.1
Descrition

## Recreating the project
This should be done using the scripts in /proj subfolder:
	- cd into <project folder>/proj
	- source ./create_project.tcl

## Create recreation script using:
	- cd into <project folder>/proj
  - execute: write_project_tcl -paths_relative_to . -origin_dir_override . -force create_project.tcl

## create IP from it:
	- cd into <project folder>/proj
	- rename IP is necessary
	- execute: source ./mkIP.tcl
	- commit changes in folders src, xgui and component.xml. Subfolder "project" might be deleted.
	- recreate depending projects

## Debugging with ILA at startup:
	- see UG908, Chapter 11, "Trigger at startup"
	a) implement design and set triggers in ILA dashboard
	b) cd to /proj folder
	c) run_hw_ila -file ila_trig.tas [get_hw_ilas hw_ila_1]
	d) open implemented design
	e) apply_hw_ila_trigger ila_trig.tas
	f) write_bitstream -force trig_at_startup.bit
	g) reopen Hardware manager and select device (xc7c020)
	h) select newly written bit file in properties window
	i) reprogram device which should then trace immediately