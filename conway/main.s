;Game Code for Conway's Game of Life
.debuginfo +

.import NES_PRG_BANKS, NES_CHR_BANKS, NES_MAPPER, NES_MIRRORING
.segment "HEADER"
	.byte 'N', 'E', 'S', $1A
	.byte <NES_PRG_BANKS
	.byte <NES_CHR_BANKS
	.byte <NES_MIRRORING
	.byte <NES_MAPPER & $F0
	.res 8, 0


.segment "VECTORS"
	.word nmi
	.word reset
	.word 0


.segment "GRAPHICS"
	.incbin "sprite_sheet.chr"


.include "maths.s"

.segment "ZEROPAGE"
R1: .res 1
R2: .res 1
R3: .res 1
R4: .res 1
R5: .res 1
R6: .res 1
R7: .res 1
R8: .res 1
nmi_tick: .res 1
background_ptr: .res 2
buttons: .res 1
index_tile: .res 2

.segment "RESET"
reset:
mainLoop:
	jsr initBackground
	jsr initPalette
	jsr initAttributes

	lda #<$2000
	sta index_tile
	lda #>$2000
	sta index_tile + 1 ;Initialize index tile

	lda #%10000000    ;Enable sprites, NMI, and nametable 0
	sta $2000         ;  write it to the PPU control register
	lda #%00011110    ;Enable sprites and background
	sta $2001
	lda $2002
	lda #$0
	sta $2006
	sta $2006
	sta $2007
	sta $2007

@wait:
	lda nmi_tick
	and #$01
	beq @wait     ;BNE should have been BEQ those are hard to get straight
	lda #0        ;Wasn't zering nmi_tick
	sta nmi_tick  ; So it just kept looping through moveIndexTile
                  ; which interacts with the PPU quickly in a loop
                  ; The result was kinda trippy and fun
	jsr readController
	jsr moveIndexTile
	lda $2002
	lda #$0
	sta $2006
	sta $2006
	sta $2007
	sta $2007
	jmp @wait


nmi:
;	lda #$00     ;Forgot what all this does
;	sta $2003    ; Well, I'll tell you what it does
;	lda #$03     ; $2003 is the OAMADDR
;	sta $4014    ; and $4014 is the is the DMA register
                 ; So writing $03 to $4014 causes everything from
                 ; $300 to $3FF to be copied to the PPU's sprite memory
                 ; I'm just guessing, but I think that this was just
                 ; filling the screen with grey sprites
                 ; Removing these 4 lines made things work better
	inc nmi_tick ;    
	rti


readController:
.scope readController
	lda #$01     ;See asm_tutorial/controller/graphics.s for comments
	sta $4016
	sta buttons
	lsr A
	sta $4016
readInputs:
	lda $4016
	lsr A
	rol buttons
	bcc readInputs

.endscope ;readController
	rts	


moveIndexTile:
.scope moveIndexTile
	;Clear the index tile
	lda $2002    ;Reset the PPU

	lda index_tile + 1	
	sta $2006
	lda index_tile
	sta $2006
	lda #$03
	sta $2007

	lda #32
	sta R3
	lda #0
	sta R4    ;Initialize second arithmetic operand with 32
	
	lda index_tile
	sta R1
	lda index_tile + 1
	sta R2    ;Initialize first arithmatic operand with the value of idext_tile

	;Update the index tile to a new position based on controller inputs
	lda buttons
	and #$08
	beq @upNotPressed
	jsr subtract16_acc
@upNotPressed:
	lda buttons
	and #$02
	beq @leftNotPressed
	jsr decrement16_acc
@leftNotPressed:
	lda buttons
	and #$04
	beq @downNotPressed
	jsr add16_acc
@downNotPressed:
	lda buttons
	and #$01
	beq @rightNotPressed
	jsr increment16_acc
@rightNotPressed:
	lda R1
	sta index_tile
	lda R2
	sta index_tile + 1

	;Highlight the new index tile
	lda $2002
	lda index_tile + 1
	sta $2006
	lda index_tile
	sta $2006
	lda #0
	sta $2007	
.endscope ;moveIndexTile
	rts


initBackground:
	lda $2002    ;Reset the PPU
	lda #$20
	sta $2006
	lda #$00
	sta $2006    ;Put $2000 into the PPU address register

	;Write 960 1's to the PPU
	ldx #$00
	ldy #$00
@writeTiles:
	lda #$03
	sta $2007
	jsr increment16_xy
	cpx #<960
	bne @writeTiles
	cpy #>960
	bne @writeTiles
	
	rts	

	
initPalette:
	lda $2002     ;Reset the PPU VRAM address
	lda #$3F
	sta $2006
	lda #$00
	sta $2006     ;Load $3F00 into the PPU address
	
	lda #$0F      ;Black
	sta $2007
	lda #$21      ;Light Blue
	sta $2007
	lda #$15      ;Red
	sta $2007
	lda #$30      ;White
	sta $2007

	rts


initAttributes:
	lda $2002    ;Reset the PPU
	lda #$23
	sta $2006
	lda #$C0
	sta $2006

	lda #0
	ldy #0
@writePalette:
	sta $2007
	iny
	cpy #64
	bne @writePalette
		
	rts


	
