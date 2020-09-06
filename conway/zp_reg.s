;;
;;  Defines General Purpose Registers R1 - R8 in Zero Page
;;

.segment "ZEROPAGE"
R1: .res 1
R2: .res 1
R3: .res 1
R4: .res 1
R5: .res 1
R6: .res 1
R7: .res 1
R8: .res 1

;Arithmatic registers for use within interrupts
R1i: .res 1
R2i: .res 1
R3i: .res 1
R4i: .res 1

;Labels must be exported before they could be imported
;Who knew?
;The linker is garbage and will not respect address as exported
;Sure, R1-R8 will be at address 0-7 in the zeropage, but so will other
;symbols deslared in other files. So there will be collisions if
;the address is specified. 
.exportzp R1 ;:= $00
.exportzp R2 ;:= $01
.exportzp R3 ;:= $02
.exportzp R4 ;:= $03
.exportzp R5 ;:= $04
.exportzp R6 ;:= $05
.exportzp R7 ;:= $06
.exportzp R8 ;:= $07
.exportzp R1i
.exportzp R2i
.exportzp R3i
.exportzp R4i
