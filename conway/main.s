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
tile_attr: .res 1
tile_color: .res 1

.segment "OAM_BUFFER"
sprite: .res $100

.segment "RESET"
reset:
mainLoop:
	jsr readController
	lda #0
	sta buttons
	jsr initBackground
	jsr initPalette
	jsr initAttributes
	jsr initCursor
	
;	lda #<$2000
;	sta index_tile
;	lda #>$2000
;	sta index_tile + 1 ;Initialize index tile
	lda $2002
	lda #$0
	sta $2006
	sta $2006
	sta $2007
	sta $2007

	lda #%10000000    ;Enable sprites, NMI, and nametable 0
	sta $2000         ;  write it to the PPU control register
	lda #%00011110    ;Enable sprites and background
	sta $2001

@wait:
	lda nmi_tick       ;Makes the response a bit snappier,
	sec
	sbc #5             ;but it still needs some tuning
	bne @wait    
	lda #0       
	sta nmi_tick 
                 
                 
	jsr readController ;Reading the controller on every loop
	jsr moveCursor
	jsr paintTile

	jmp @wait


nmi:
	lda #$00     ;Forgot what all this does
	sta $2003    ; Well, I'll tell you what it does
	lda #>sprite ; $2003 is the OAMADDR
	sta $4014    ; and $4014 is the is the DMA register
                 ; So writing $03 to $4014 causes everything from
                 ; $300 to $3FF to be copied to the PPU's sprite memory
                 ; I'm just guessing, but I think that this was just
                 ; filling the screen with grey sprites
                 ; Removing these 4 lines made things work better
	lda #23
	sta $2006
	lda tile_attr
	sta $2006
	lda tile_color
	sta $2007
	lda #$C0
	sta tile_color
	
	lda #0
	sta $2006
	sta $2006
	sta $2007
	sta $2007

	inc nmi_tick ;    
	rti


readController:
	lda #$01     ;See asm_tutorial/controller/graphics.s for comments
	sta $4016
	sta buttons
	lsr A
	sta $4016
@readInputs:
	lda $4016
	lsr A
	rol buttons
	bcc @readInputs

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



initCursor:
	lda #0     
	sta sprite     ;Start cursor at 0 x position
	lda #1 
	sta sprite + 1 ;Load tile 0 into curspr
	lda #0
	sta sprite + 2 ;Zero attributes
	lda #0
	sta sprite + 3 ;Start cursor at 0 y position
	rts


moveCursor:
	lda buttons
	and #$08
	beq @upNotPressed
	lda sprite
	sec
	sbc #8
	sta sprite
@upNotPressed:
	lda buttons
	and #$04
	beq @downNotPressed
	lda sprite
	clc
	adc #8
	sta sprite
@downNotPressed:
	lda buttons
	and #$02
	beq @leftNotPressed
	lda sprite + 3
	sec
	sbc #8
	sta sprite + 3
@leftNotPressed:
	lda buttons
	and #$01
	beq @rightNotPressed
	lda sprite + 3
	clc
	adc #8
	sta sprite + 3
@rightNotPressed:
	
	rts

;When A-button is pressed, color the tile
; when B-button is pressed, clear the tile
; To color the tile, first find the address of the attributes
; table that corresponds to the cursor location. Then store this
; value in a global. Then on the v-sync, write to this address
; to change the color of the tile
; To clear, do the same, except write 0 to the address
; The address is computed by:
; Starting at 23C0 - 23FF each address represents 2x2 tile region
; 23C0 - 23C7 is the top row
; 23C8 - 23CF is the next row
; and so on
; So do cursor sprite y position / 8 (>> 3) to get the y tile offset
; and shift it up 4, then add it to 23C0 (the base address)
; Then get the cursor sprite x position / 8 and add to the result
paintTile: 
	lda sprite       ;Load the cursor y position
;	asl              ;Something is wrong here. I don't get it
	lsr              ;(cursor y >> 3) << 4
	clc
	adc #$C0         ;Add to the low byte of the base address
	sta tile_attr    ;Put it into the tile attributes address
	                 ;To be written to in v-sync
	lda sprite + 3   ;Load the cursor x position
	lsr              ;
	lsr              ;
	lsr              ;cursor x / 8 (>> 3)
	clc
	adc tile_attr    ;Add x tile position to the y offset
	sta tile_attr
	lda buttons
	and #$80
	beq @aNotPressed
	lda #1
	sta tile_color
@aNotPressed:
	lda buttons
	and #$40
	beq @bNotPressed
	lda #0
	sta tile_color
@bNotPressed:

	rts
