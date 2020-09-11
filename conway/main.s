;Game Code for Conway's Game of Life
.debuginfo +

.include "maths.inc"
.include "zp_reg.inc"
.include "pop_slide.inc"

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


.segment "ZEROPAGE"
nmi_tick: .res 1
nmi_tick_count: .res 1
background_ptr: .res 2
inputs: .res 1
mask: .res 1
buttons: .res 1
index_tile: .res 2
tile_addr: .res 16
tile_color: .res 1
update_request: .res 1
game_map_addr: .res 2
map_offset: .res 2


.segment "NT_BUFFER"
nt_buffer: .res 160

.segment "OAM_BUFFER"
sprite: .res $100

.segment "BSS"
game_map: .res 960

.segment "RESET"
reset:
mainLoop:
	ldx #$FF
	txs     ;Initialize the stack pointer. It is not init'd on reset

	lda #$20
	sta tile_addr + 1
	lda #0
	sta tile_addr
	
	lda #<game_map
	sta game_map_addr
	lda #>game_map
	sta game_map_addr + 1

	lda #0
	sta map_offset
	sta map_offset + 1

	lda #$FF
	sta mask
	jsr readController
	lda #0
	sta buttons
	jsr initBackground
	jsr initPalette
	jsr initAttributes
	jsr initCursor
	
	lda $2002
	lda #$0
;	sta $2005
	sta $2006
	sta $2006
	sta $2007
	sta $2007

	lda #%10000000    ;Enable sprites, NMI, and nametable 0
	sta $2000         ;  write it to the PPU control register
	lda #%00011110    ;Enable sprites and background
	sta $2001

@wait:
	lda nmi_tick
	beq @wait
	lda #0
	sta nmi_tick
	jsr	paintBackground

	inc nmi_tick_count
	lda #2
	cmp nmi_tick_count
	bne @wait
	lda #0       
	sta nmi_tick_count 
                 
	jsr readController 
	jsr moveCursor
;	jsr paintTile
	lda tile_color
	eor #3
	sta tile_color
	jsr updateBackground
	jmp @wait


nmi:
	php    ;
	pha    ;  Prevent race conditions
	txa    ;  By pushing the registers to the stack
	pha    ;  then popping them before exiting

	lda #$00     ;Forgot what all this does
	sta $2003    ; Well, I'll tell you what it does
	lda #>sprite ; $2003 is the OAMADDR
	sta $4014    ; and $4014 is the is the DMA register
                 ; So writing $03 to $4014 causes everything from
                 ; $300 to $3FF to be copied to the PPU's sprite memory
                 ; I'm just guessing, but I think that this was just
                 ; filling the screen with grey sprites
                 ; Removing these 4 lines made things work better

;	lda $2002
	lda #0
	cmp update_request
	beq @no_update_requested 

	

	lda tile_addr + 1
	sta $2006
	lda tile_addr
	sta $2006
	jsr popSlide

;	ldy #(32 * 4)
;	dey
;@copy_tiles:
;	pla 
;	sta $2007
;	dey               ;
;	bpl @copy_tiles           ;

	lda #0
	sta $2006
	sta $2006
	sta $2007
;	sta $2007
@no_update_requested:

	inc nmi_tick ;    

	pla    ; Pop the registers before returning
	tax    ;
	pla    ;
	plp    ;
	rti


readController:
	lda #$01     ;See asm_tutorial/controller/graphics.s for comments
	sta $4016
	sta inputs
	lsr A
	sta $4016
@readInputs:
	lda $4016
	lsr A
	rol inputs
	bcc @readInputs

	;Mask the input register to prevent multiple button presses
	;	For a new button press to be registered, the button must
	;	be released first
	lda mask    ;Load the inverted input state from the pervious read
	and inputs  ;And it (mask it) with the current input atate
	sta buttons ;Save the result to the button register
	lda inputs  ;Load the unmodified input state
	eor #$FF    ;Inverter it
	sta mask    ;Store it as the mask for the next read
	
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


;FIXME: The cursor appears to be off by 1 horizontal scan line.
;When loading it at position 0, it's drawn at postion 1
;Loading it a 0xFF makes it disappear since that pos is off screen
;Tried removing all the code except the DMA stuff; didn't help
initCursor:
	lda #8     
	sta sprite     ;Start cursor at 0 y position
	lda #1 
	sta sprite + 1 ;Load tile 1 into cursor
	lda #0
	sta sprite + 2 ;Zero attributes
	lda #0
	sta sprite + 3 ;Start cursor at 0 x position
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
	sta R5
;	sta tile_addr
	lda R2
	sta R6
;	sta tile_addr + 1

	lda sprite + 3
	sta R1
	lda #0
	sta R2
	jsr shift16_right_acc
	jsr shift16_right_acc
	jsr shift16_right_acc
;	lda tile_addr + 1
	lda R6
	sta R4
;	lda tile_addr
	lda R5
	sta R3
	jsr add16_acc 

	;This is just a test
	lda R1
	sta R5
	lda R2
	sta R6

	lda sprite + 3
	sta R3
	lda sprite
	sta R4
	jsr findLowerRightNeighbour
	lda R1
	sta tile_addr
	lda R2
	sta tile_addr + 1

	lda R5
	sta R1
	lda R6
	sta R2
	lda sprite + 3
	sta R3
	lda sprite
	sta R4
	jsr findUpperRightNeighbour
	lda R1
	sta tile_addr + 2
	lda R2
	sta tile_addr + 3


	lda R5
	sta R1
	lda R6
	sta R2
	lda sprite + 3
	sta R3
	lda sprite
	sta R4
	jsr findUpperLeftNeighbour
	lda R1
	sta tile_addr + 4
	lda R2
	sta tile_addr + 5

	lda R5
	sta R1
	lda R6
	sta R2
	lda sprite + 3
	sta R3
	lda sprite
	sta R4
	jsr findLowerLeftNeighbour
	lda R1
	sta tile_addr + 6
	lda R2
	sta tile_addr + 7
	;That was just a test

	

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

;Find the neighbour to the left of an index
;@param R1 - index position low byte
;@param R2 - index position high byte
;@param R3 - index x position
;@return R1 - Left Neighbour Position low byte
;@return R2 - Left Neighbour Position high byte
findLeftNeighbour:
	sec
	lda R3
	sbc #8
	bcc @wrapAround 
	jsr decrement16_acc
	rts
@wrapAround:
	lda #31
	sta R3
	lda #0
	sta R4
	jsr add16_acc
	rts



;Find the neighbour to the right of an index
;@param R1 - index position low byte
;@param R2 - index position high byte
;@param R3 - index x position
;@return R1 - Right Neighbour Position low byte
;@return R2 - Right Neighbour Position high byte
findRightNeighbour:
	clc
	lda R3
	adc #8
	bcs @wrapAround
	jsr increment16_acc
	rts
@wrapAround:
	lda #31
	sta R3
	lda #0 
	sta R4
	jsr subtract16_acc
	rts
	

;Find the neighbour above an index
;@param R1 - index position low byte
;@param R2 - index position high byte
;@param R3 - index y position
;@param R1 - Upper Neighbour Position low byte
;@param R2 - Upper Neighbour Position high byte
findUpperNeighbour:
	lda R3
	beq @wrapAround
	lda #32
	sta R3
	lda #0
	sta R4
	jsr subtract16_acc
	rts
@wrapAround:
	lda #<928
	sta R3
	lda #>928
	sta R4
	jsr add16_acc
	rts


;Find the neighbour below an index
;@param R1 - index position low byte
;@param R2 - index position high byte
;@param R3 - index y position
;@return R1 - Lower Neighbour Position low byte
;@return R2 - Lower Neighbour Position high byte
findLowerNeighbour:
	lda R3
	cmp #232
	beq @wrapAround
	lda #32
	sta R3
	lda #0
	sta R4
	jsr add16_acc
	rts
@wrapAround:
	lda #<928
	sta R3
	lda #>928
	sta R4
	jsr subtract16_acc
	rts


;Find the neighbour above and to the left of an index
;@param R1 - index position low byte
;@param R2 - index position high byte
;@param R3 - index x position
;@param R4 - index y position
;@return R1 - Upper Left Neighbour Position low byte
;@return R2 - Upper Left Neighbour Position high byte
findUpperLeftNeighbour:
	lda R4
	pha
	jsr findLeftNeighbour
	pla
	sta R3
	jsr findUpperNeighbour
	rts



;Find the neighbour below and to the left of an index
;@param R1 - index position low byte
;@param R2 - index position high byte
;@param R3 - index x position
;@param R4 - index y position
;@return R1 - Lower Left Neighbour low byte
;@return R2 - Lower Left Neighbour high byte
findLowerLeftNeighbour:
	lda R4
	pha
	jsr findLeftNeighbour
	pla
	sta R3
	jsr findLowerNeighbour
	rts


;Find the neighbour	above and to the right of an index
;@param R1 - index position low byte
;@param R2 - index position high byte
;@param R3 - index x position
;@param R4 - index y position
;@return R1 - Upper Right Neighbour low byte
;@return R2 - Upper Right Neighbour high byte
findUpperRightNeighbour:
	lda R4
	pha
	jsr findRightNeighbour
	pla
	sta R3
	jsr findUpperNeighbour
	rts


;Find the neighbour	below and to the right of an index
;@param R1 - index position low byte
;@param R2 - index position high byte
;@param R3 - index x position
;@param R4 - index y position
;@return R1 - Lower Right Neighbour low byte
;@return R2 - Lower Right Neighbour high byte
findLowerRightNeighbour:
	lda R4
	pha
	jsr findRightNeighbour
	pla
	sta R3
	jsr findLowerNeighbour
	rts


;@param R5 - Background color
updateBackground:
	lda #<game_map
	sta R1
	lda #>game_map
	sta R2
	lda #<960
	sta R3
	lda #>960
	sta R4
	lda tile_color
	sta R5
	jsr memset16
	rts


paintBackground:
	;Add map_offset to game_map ;
	lda map_offset              ;
	sta R1                      ;
	lda map_offset + 1          ;
	sta R2                      ;
	lda #<game_map + (32 * 4)   ;
	sta R3                      ;
	lda #>game_map + (32 * 4)   ;
	sta R4                      ;
	jsr add16_acc               ;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	lda #<(game_map + (32 * 4))
	sta R3
	lda #>(game_map + (32 * 4))
	sta R4
	
;	lda #(32 * 4)
;	sta R5
;	jsr memmove8
		
	ldy #((32 * 4) - 1)
@pushLoop:
	lda (R1), Y
	sta (R3), Y
	dey
	bpl @pushLoop
	
	lda #1
	sta update_request

	;Increment map_offset in (32 * 4) byte chunks until it's > 960
	lda map_offset
	sta R1
	lda map_offset + 1
	sta R2
	lda #<(960 - (32 * 4))
	sta R3
	lda #>(960 - (32 * 4))
	sta R4
	jsr is_greater16
	bne @noOffsetReset

	lda #0
	sta map_offset
	sta map_offset + 1
	sta tile_addr
	lda #$20
	sta tile_addr + 1
	rts

@noOffsetReset:
	lda #<(32 * 4)
	sta R3
	lda #>(32 * 4)
	sta R4
	jsr add16_acc
	lda R1
	sta map_offset
	lda R2
	sta map_offset + 1
	lda tile_addr
	sta R1
	lda tile_addr + 1  ;Never update tile_addr unless update_request is clear
	sta R2
	jsr add16_acc
	lda R1
	sta tile_addr
	lda R2
	sta tile_addr + 1
	rts


;@param R1 - Base address low byte
;@param R2 - Base address high byte
;@param R3 - Count low byte
;@param R4 - Count high byte
;@param R5 - Set value
memset16:
	ldy #0
	ldx #0
@writeLoop:
	lda R5
	sta (R1), Y
	iny
	bne @noIncMSB
	inc R2
	inx
@noIncMSB:
	cpy R3
	bne @writeLoop
	cpx R4
	bne @writeLoop
	rts 


;Set up to 255 bytes of a block of memory to a specified value
;@param R1 - Base address low byte
;@param R2 - Base address high byte
;@param R3 - Set value
;@param R4 - Number of bytes to set
memset8:
	ldy #0
@writeLoop:
	lda R3
	sta (R1), Y
	iny
	cpy R4
	bne @writeLoop
	rts
	
	
	
;Copy a block of memory to another location; up to 255 bytes
;@param R1 - Destination address low byte
;@param R2 - Destination address high byte
;@param R3 - Source address low byte
;@param R4 - Source address high byte
;@param R5 - Number of bytes to copy
memmove8:
	ldy #0
@copyLoop:
	lda (R3), Y
	sta (R1), Y
	iny
	cpy R5
	bne @copyLoop
	rts
		
	
