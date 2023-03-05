If you want to use One click project processing then:
   - make a script project to hold both .pas files.

Can process LibPkg (IntLib) & board projects.

CompSourceLibReLinker.pas 
These exposed procedure entry points are setup for single focused document action.
- SchDoc/Lib relinking
- PcbDoc FP relinking

PrjLibReLinker.pas
These exposed procedure entry points are setup to iterate over all project (board or LibPkg) documents
in the sequence:-
- SchLib, to link FPmodels to source PcbLib(s)
- SchDoc, to link comps & comp models to source libs
- PcbDoc, to link footprints to source PcbLib(s)

All summary reports are created in subfolder "Reports"

version AD19+ :
Alternative DMObjects method as ISch_Implementation has issues
Has to compile each Sheet.
