.include "zp_reg.inc"

.segment "RESET"


popSlide:
	tsx
	stx R1i
	ldx #159
	txs
.repeat (32 * 4)
	pla
	sta $2007
.endrepeat
	ldx R1i
	txs
	rts
.export popSlide
