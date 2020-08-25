;Simple Maths Library
;See licence.txt for licence information

;.import R1, R2, R3, R4, R5, R6, R7, R8
.globalzp R1, R2, R3, R4, R5, R6, R7, R8 ;Including this made a warning go away
                                ;Warning: Didn't use zeropage addressing for R1
                                ;It defines R1-R8 as zeropage labels
                                ;There is also .importzp and .exportzp
                                ;Which look like they do similar things
                                ;Not sure what the best approach is

.segment "ZEROPAGE"

result16: .res 2
argx8: .res 1
argy8: .res 1


.segment "RESET"

multiply8:
	lda #$80
	sta result16
	asl A	 
	dec argx8
@loop:
	lsr argy8
	bcc @skipAdd
	adc argx8
@skipAdd:
	ror A
	ror result16
	bcc @loop
	sta result16 + 1


;Decrement a 16-bit number using general purpose (zeropage) registers
;@param R1 - Low Byte
;@raram R2 - High Byte
;@return R1 - Decremented low byte
;@return R2 - Decremented high byte
decrement16_acc:
	lda R1     ;Move low byte into A to test if Zero
	bne @skip  ;If low byte is zero
	dec R2     ; Decrement high byte
@skip:
	dec R1     ;Then decrement low byte
	rts


;Increment a 16-bit number using general purpose (zeropage) registers
;@param R1 - Low Byte
;@raram R2 - High Byte
;@return R1 - Decremented low byte
;@return R2 - Decremented high byte
increment16_acc:
	inc R1     ;Increment the low byte
	bne @skip  ;If low byte iz zero (overflowed)
	inc R2     ; increment high byte
@skip:
	rts


;Increment a 16-bit number using x and y registers
;@param X - Low byte
;@param Y - High byte
;@return X - Incremented low byte
;@return Y - Incremented high byte
increment16_xy:
	inx         ;Increment low byte
	bne @skip   ;If low byte is 0 (overflow)
	iny         ;  increment high byte
@skip:          ;
	rts	

;Add two 16-bit numbers
;@param R! - First operand low byte
;@param R2 - First operand high byte
;@param R3 - Second operand low byte
;@param R4 - Second operand high byte
;@return R1 - Result low byte
;@return R2 - Result high byte
add16_acc:
	clc      ;Clear the carry flag before addition
	lda R1   ;Put the first low byte into A
	adc R3   ;Add the second low  byte to A
	sta R1   ;Store the result low byte
	lda R2   ;Put the first high byte into A
	adc R4   ;Add the second high byte to A, the carry flag will do it's thing
	sta R2   ;Store the result high byte
	rts


;Subtract two 16-bit numbers
;@param R1 - First operand low byte
;@param R2 - First operand high byte
;@param R3 - Second operand low byte
;@param R4 - Second operand high byte
;@return R1 - Result low byte
;@return R2 - Result high byte
subtract16_acc:
	sec      ;Set the carry flag before subtraction
	lda R1   ;Put the first low byte into A
	sbc R3   ;Subtract the second low byte from A
	sta R1   ;Store the result low byte
	lda R2   ;Put the first high byte into A
	sbc R4   ;Subtract the second high byte from A
	sta R2   ;Strore the result high byte
	rts


;Shift a 16-bit number to the right
;@param R1 - low byte
;@param R2 - high byte
;@return R1 - Result low byte
;@return R2 - Result high byte
shift16_right_acc:
	lda R2    ;Load the high byte
	lsr       ;Down shift the high byte, bit 0 will shift into carry
	sta R2    ;Save the new high byte
	ror R1    ;Down shift the low byte, carry will shift into bit 7
	rts


;Shift a 16-bit number to the left
;@param R1 - low byte
;@param R2 - high byte
;@return R1 - Result low byte
;@return R2 - Result high byte
shift16_left_acc:
	lda R1    ;Load the low byte
	asl       ;Up shift the low byte; bit 7 will shift into carry
	sta R1    ;Save the new low byte
	rol R2    ;Up shift the high byte, carry will shift into bit 0
	rts


;;;;;Decrement a 16-bit number
;;;;;@param X - Low byte
;;;;;@param Y - High byte
;;;;;@return X - Decremented low byte
;;;;;@return Y - Decremented high byte
;;;;.macro DECREMENT_16
;;;;.scope
;;;;	txa        ;Move low byte into A to test if zero
;;;;	bne @skip  ;If low byte == 0
;;;;	dey        ;  decrement high byte
;;;;@skip:         ;
;;;;	dex        ;Decrement low byte
;;;;.endscope      ;
;;;;.endmacro      ;
;;;;
;;;;
;;;;;Increment a 16-bit number
;;;;;@param X - Low byte
;;;;;@param Y - High byte
;;;;;@return X - Incremented low byte
;;;;;@return Y - Incremented high byte
;;;;.macro INCREMENT_16
;;;;.scope
;;;;	inx         ;Increment low byte
;;;;	txa         ;Move low byte into A to test if zero (overflow)
;;;;	bne @skip   ;If low byte == 0
;;;;	iny         ;  increment high byte
;;;;@skip:          ;
;;;;.endscope       ;
;;;;.endmacro       ;
;;;;
;;;;
;;;;;Add an immediate value to a 16-bit number
;;;;;@param X - Param 1 low byte
;;;;;@param Y - Param 2 high byte
;;;;;@param IVAL - Immediate value
;;;;;@Return X - Result low byte
;;;;;@Return Y - Result high byte
;;;;.macro ADD_16_IMMEDIATE ;IVAL
;;;;	clc           ;Clear carry flag before addition
;;;;	txa           ;Load the low byte into A
;;;;	;Add low byte of immedieate value
;;;;;	adc #<(.right (.tcount ({IVAL}) - 1,  {IVAL})) 
;;;;	tax           ;Store the result back in X
;;;;	tya           ;Load the high byte into A
;;;;    ;Add the high bytes, let the carry flag do its thing
;;;;;	adc #>(.right (.tcount ({IVAL}) - 1, {IVAL})
;;;;	tay           ;Store the low byte back in y
;;;;.endmacro
;;;;	
;;;;
;;;;;.macro IS_IMMEDIATE ARG
;;;;;;	.out "Macro IS_IMMEDIATE"
;;;;;;	.out (.string ({ARG}))
;;;;;	(.match (.left (1, {ARG}), #))
;;;;;.endmacro
;;;;
;;;;.macro CHECK_IMMEDIATE ARG
;;;;	.out "Macro CHECK_IMMEDIATE"
;;;;	.if !(.match (.left (1, {ARG}), #))
;;;;		.error "Argument must be an immediate value"
;;;;	.endif
;;;;.endmacro
;;;;
;;;;;Subtract an immediate value from a 16=bit number
;;;;;@param X - Param 1 low byte
;;;;;@param Y - Param 2 high byte
;;;;;@param IVAL - Immediate value
;;;;;@Return Y - Result low byte
;;;;;@Return A - Result high byte
;;;;.macro SUB_16_IMMEDIATE IVAL
;;;;;	CHECK_IMMEDIATE ({IVAL})
;;;;	.if !(.match (.left (1, {IVAL}), #))
;;;;		.error "Argument must be an immediate value"
;;;;	.endif
;;;;	sec           ;Set the carry flag before subtraction
;;;;	txa           ;Load the lig byte into A
;;;;    ;Subtract low byte of IVAL from the low byte
;;;;	sbc #<(.right (.tcount ({IVAL})-1, {IVAL}))
;;;;	tax           ;Store the result back in X
;;;;	tya           ;Load the high byte into A
;;;;	sbc #>(.right (.tcount ({IVAL})-1, {IVAL}))
;;;;	tay           ;Store the result back in Y
;;;;.endmacro
