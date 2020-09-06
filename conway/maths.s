;Simple Maths Library
;See licence.txt for licence information


.include "zp_reg.inc"

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
.export multiply8


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
.export decrement16_acc


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
.export increment16_acc


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
.export increment16_xy


;Add two 16-bit numbers
;@param R1 - First operand low byte
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
.export add16_acc


;Add two 16-bit numbers from within an interrupt routine
;@param R1i - Fisrt operand low byte
;@param R2i - First operand high byte
;@param R3i - Second operand low byte
;@param R4i - Second operand high byte
add16_acc_int:
	clc
	lda R1i
	adc R3i
	sta R1i
	lda R2i
	adc R4i
	sta R2i
	rts
.export add16_acc_int


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
.export subtract16_acc


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
.export shift16_right_acc


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
.export shift16_left_acc


