;NES assembler tutorial, and maybe boilerplate

.import NES_PRG_BANKS, NES_CHR_BANKS, NES_MAPPER, NES_MIRRORING
.segment "HEADER"
	.byte 'N', 'E', 'S', $1A
	.byte <NES_PRG_BANKS
	.byte <NES_CHR_BANKS
	.byte <NES_MIRRORING
	.byte <NES_MAPPER & $F0
	.res 8, 0

.segment "ZEROPAGE"
	.res 42, 0           ;Other source suggests the first 42 bytes are reserved
backgroundPtr: .res 2    ;Used to write background data to the PPU
buttons: .res 1          ;Store value of controller inputs
velocity: .res 1
nmiTick: .res 1

;Load the background data in background.s and write it to the PPU
.segment "RESET"
reset:
mainLoop:
	JSR loadBackground
	JSR loadPalette
	JSR loadAttributes
	JSR loadSprite
	LDA #%10000000    ;Byte enabling NMI, sprites, and nametable 0 background
	STA $2000         ; write it to the PPU control register
	LDA #%00011110    ;Byte enabling sprites and background
	STA $2001         ; write it to the PPU mask register
	LDA #$00          ;Disable background scrolling
	STA $2006         ;
	STA $2006         ;Clear contents of address register
	STA $2007         ;
	STA $2007         ; and data register
	
wait:
	LDA nmiTick
	LSR A
	STA nmiTick
	BNE wait
;	JSR readController
	JSR moveSpaceShip
	JMP wait

nmi:
	LDA #$00
	STA $2003
	LDA #$03
	STA $4014
	LDA #$01
	STA nmiTick
	RTI

;The controller's input value lives in a shift register
; with each sucessive read from the controller's address ($4016)
; one bit of the shift register is read, then shifted out
; This reads all 8 bits from the controller, and shifts them into a
; byte in memory for later processing
readController:
	LDA #$01     ;Writing 1 to the controller register latches button presses
	STA $4016    ; into the shift register
	STA buttons  ;Init buttons with 1. When the 1 is shifted out, the loop ends
	LSR A        ;A is now zero.
	STA $4016    ; Clearing the latch makes the controller readable
@readInputs:
	;The buttons are shifted in in the following order:
	; A, B, Select, Start, Up, Down, Left, Right 
	LDA $4016    ;Read a bit from the controller shift register
	LSR A        ;If the button is presses, 1 will shift into the carry bit
	ROL buttons  ;buttons <<= 1; if carry is set, it will shift into bit 0
	BCC @readInputs

	RTS


;Respond to controller inputs to move the spaceship around the screen
; All inputs are checked allowing the spaceship to move diagonally
moveSpaceShip:
	LDX #$FF             ;Load the velocity (-1) into X
	LDA buttons          ;Stick the buttons register into the accumulater
	AND #$08             ; and check if up was pressed
	BEQ @upNotPressed    ;If Up was pressed, call moveUpDown with 
	JSR moveUpDown       ; velocity set to -1
@upNotPressed:           ; else, keep checking
	LDA buttons          ;Load the buttons register again
	AND #$02             ; and check if Left was pressed
	BEQ @leftNotPressed  ;If Left was pressed, call moveLeftRight with
	JSR moveLeftRight    ; velocity set to -1
@leftNotPressed:         ; else, keep checking
	LDX #$01             ;Load the velocity (1) into X
	LDA buttons          ;Load the buttons register yet again
	AND #$04             ; and check if Down was pressed
	BEQ @downNotPressed  ;If Down was pressed, call moveUpDown
	JSR moveUpDown       ; with velocity set to 1
@downNotPressed:         ; else, keep checking
	LDA buttons          ;Load the buttons register one final time
	AND #$01             ; and check if the Right button was pressed
	BEQ @rightNotPressed ;If Right was pressed, call moveLeftRight
	JSR moveLeftRight    ; with velocity set to 1
@rightNotPressed:
	RTS

;Move the space ship up or down depending on the value of X (velocity)
moveUpDown:
	STX velocity

	LDA $300
	CLC
	ADC velocity
	STA $300
	STA $304
	STA $308

	LDA $30C
	CLC
	ADC velocity
	STA $30C
	STA $310
	STA $314

	RTS

;Move the space ship right or left depending on the value of X (velocity)
moveLeftRight:
	STX velocity
	
	LDA $303
	CLC
	ADC velocity
	STA $303
	STA $30F

	LDA $307
	CLC
	ADC velocity
	STA $307
	STA $313

	LDA $30B
	CLC
	ADC velocity
	STA $30B
	STA $317

	RTS
		
;Load the background data in background.s and write it to the PPU
loadBackground:
	LDA $2002    ;Reset the PPU
	LDA #$20     ;Store $2000 to $2006
	STA $2006    ; $2000 is the address of nametable 0
	LDA #$00     ; $2006 is the memory-mapped address register
	STA $2006    ; that points to the PPU
	
	LDA #<background        ;Take the address of background
	STA backgroundPtr       ; and put it into the background
	LDA #>background        ; pointer in ram
	STA backgroundPtr + 1   ;
 
	;Simple memcpy implementation
	;Copies 960 bytes from background to the PPU nametable
	;There may be a more optimized way to do this
	;  I'm still learning	
	LDX #$00                  ;Clear X and Y registers
	LDY #$00                  ;for the loop counters and indecies
@bgwrite:                     ;Write the contents of background in a loop
	LDA (backgroundPtr), Y    ;Use parens to do inderect indexed memory access
	STA $2007                 ; *ppu_data = backgroundPtr[Y] where Y is uint8_t
	
	INY                       ;Increment the index formed by (X << 8) & Y
	BNE @skipinc              ;
	INX                       ;Increment X when Y overflows
	INC backgroundPtr + 1     ;Also increment backgroundPtr high byte
@skipinc:                     ;

	CPY #<960                 ;Compare Y with the low byte of 960
	BNE @bgwrite              ; 960 is the size of the background
	CPX #>960                 ;Compate X with the high byte of 960 
	BNE @bgwrite              ;Keep looping if 960 != ((X << 8) & Y)

	RTS	
	

;Write the palette data in palette.s to the PPU
loadPalette:
	LDA $2002    ;Reset the PPU
	LDA #$3F	 ;Store $3F00 to PPU address register
	STA $2006    ;  3F00 must be the palette register
	LDA #$00     ;
	STA $2006    ;

	LDY #$00
@palwrite:
	LDA palette, Y
	STA $2007        

	INY
	CPY #32
	BNE @palwrite

	RTS


;Write the attribute date in attributes.s to the PPU
loadAttributes:
	LDA $2002    ;Reset the PPU. Is that actually what that does?
	LDA #$23     ;Store 23C0 (Attributes register) to the PPU address register
	STA $2006    ; 
	LDA #$C0     ;
	STA $2006    ;

	LDY #$00
@attwrite:
	LDA attributes, Y
	STA $2007
	
	INY
	CPY #64
	BNE @attwrite

	RTS


loadSprite:
	LDX #$00
@spritewrite:
	LDA sprites, X
	STA $300, X
	INX
	CPX 24
	BNE @spritewrite
	
	RTS


.segment "VECTORS"
	.word nmi
	.word reset
	.word 0


.segment "GRAPHICS"
	.incbin "sprite_sheet.chr"

.segment "BACKGROUND"
background: .include "background.s"

.segment "PALETTE"
palette:    .include "palette.s"
attributes: .include "attributes.s"

.segment "SPRITES"
sprites: .include "sprites.s"
