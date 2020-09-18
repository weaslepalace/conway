POP_SLIDE_SRC = 1
.include "pop_slide.inc"
.include "zp_reg.inc"

.segment "RESET"

popSlide:
	txa
	pha
	tsx
	stx R1i
	ldx #$FF
	txs

	ldx #POP_SLIDE_N_LINES
@slide:
.repeat 32
	pla
	sta $2007
.endrepeat
	dex
	beq @slideDone ;bne is a relative jump that adds +127 or -128 to the PC
	jmp @slide     ;Trying to jumb beyone that requires absolute jmp
@slideDone:

	ldx R1i
	txs
	pla
	tax
	rts
.export popSlide
