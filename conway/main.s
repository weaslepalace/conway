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
tile_addr: .res 2
tile_color: .res 1
update_request: .res 1

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
	lda #0
	cmp update_request
	beq @no_update_requested 
	lda tile_addr + 1
	sta $2006
	lda tile_addr
	sta $2006
	lda tile_color
	sta $2007
	
	lda #0
	sta $2006
	sta $2006
	sta $2007
	sta $2007
@no_update_requested:

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
	lda #$02
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
	
	;Palette 0
	lda #$0F      ;Black
	sta $2007
	lda #$21      ;Light Blue
	sta $2007
	lda #$15      ;Magenta
	sta $2007
	lda #$30      ;White
	sta $2007

	;Palette 1
	lda #$0F      ;Black
	sta $2007
	lda #$30      ;White
	sta $2007
	lda #$21      ;Light Blue
	sta $2007
	lda #$0F      ;Black
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



paintTile:
	lda sprite
	and #$F8
	sta R1
	lda #0
	Sta R2
	jsr shift16_left_acc
	jsr shift16_left_acc
	lda #$20
	sta R4
	lda #0
	sta R3
	jsr add16_acc
	lda R1
	sta tile_addr
	lda R2
	sta tile_addr + 1

	lda sprite + 3
	sta R1
	lda #0
	sta R2
	jsr shift16_right_acc
	jsr shift16_right_acc
	jsr shift16_right_acc
	lda tile_addr + 1
	sta R4
	lda tile_addr
	sta R3
	jsr add16_acc 
	lda R1
	sta tile_addr
	lda R2
	sta tile_addr + 1

	lda buttons
	and #$80
	beq @aNotPressed
	lda #$00
	sta tile_color
	lda #1
	sta update_request
	rts
@aNotPressed:
	lda buttons
	and #$40
	beq @bNotPressed
	lda #02
	sta tile_color
	lda #1
	sta update_request
	rts
@bNotPressed:
	lda #0
	sta update_request
	rts


