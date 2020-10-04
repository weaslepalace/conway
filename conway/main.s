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
	.word debug


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
tile_addr: .res 2
tile_color: .res 1
update_request: .res 1
update_ack: .res 1
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

	bit $2002
@initWait1:
	bit $2002
	bpl @initWait1

	lda #<game_map
	sta game_map_addr
	sta R1
	lda #>game_map
	sta game_map_addr + 1
	sta R2
	lda #<960
	sta R3
	lda #>960
	sta R4
	lda #0
	jsr memset16 

	lda #0
	sta map_offset
	sta map_offset + 1
	sta tile_addr
	lda #$20
	sta tile_addr + 1

	lda #$FF
	sta mask
	jsr readController
	lda #0
	sta buttons
	jsr initBackground
	jsr initPalette
	jsr initAttributes
	jsr initCursor

@initWait2:
	bit $2002
	bpl @initWait2

	lda #$0
	sta $2006
	sta $2006
	sta $2007
	sta $2007

	lda #%10000000    ;Enable sprites, NMI, and nametable 0
	sta $2000         ;  write it to the PPU control register
	lda #%00011110    ;Enable sprites and background
	sta $2001

	lda #1
	sta update_ack

@setupLoop:
	jsr lifeExecute
	lda nmi_tick
	beq @setupLoop
	lda #0
	sta nmi_tick
	jsr	paintBackground
	jsr updateOffsets

	inc nmi_tick_count
	lda #8
	cmp nmi_tick_count
	bne @setupLoop
	lda #0       
	sta nmi_tick_count 

	jsr readController 

	lda buttons	;Pressing start of select will 
	and #$30    ;exit the setup phase and start the game
	bne @exitSetupLoop

	jsr moveCursor
	jsr paintTile 

	jmp @setupLoop

@exitSetupLoop:
	lda #$FF    ;Hide the cursor from here on
	sta sprite  ;
	lda #60
	sta nmi_tick_count

@gameLoop:
	lda nmi_tick
	beq @gameLoop
	lda #0
	sta nmi_tick

	jsr paintBackground
	jsr updateOffsets

;	dec nmi_tick_count
;	beq @gameLoop
;	lda #5
;	sta nmi_tick_count
;
	jsr lifeExecute		

	jmp @gameLoop
	

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

	lda #0
	sta $2006
	sta $2006
	
	lda #1
	sta update_ack
@no_update_requested:
	lda #0
	sta update_request

	inc nmi_tick ;    

	pla    ; Pop the registers before returning
	tax    ;
	pla    ;
	plp    ;
	rti


debug:
	jmp reset


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
	;Fun limitation:
	;Sprites are delayed 1 scanline, so writing 7 puts the top pixel at line 8
	;Writing $FF hides the entier sprite
	;It's therefore impossible to show a sprite at line zero
	lda #7
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
	cmp #$FF           ;Check for sprite underflow
	bne @upNotPressed  ;If underflow occurs
	lda #(239 - 8)     ;Set sprite to the bottom row of tiles
	sta sprite         ;
@upNotPressed:
	lda buttons
	and #$04
	beq @downNotPressed
	lda sprite
	clc
	adc #8
	sta sprite
	cmp #$EF            ;Check for sprite overflow
	bne @downNotPressed ;If overflow occurs
	lda #7              ;Set sprite to the top row of tiles
	sta sprite          ;
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
	lda buttons
	and #$80
	beq @aNotPressed
	lda #$00
	sta tile_color
	lda #1
	jsr @stroke
	rts
@aNotPressed:
	lda buttons
	and #$40
	beq @bNotPressed
	lda #01
	sta tile_color
	lda #1
	jsr @stroke
	rts
@bNotPressed:
	rts

@stroke:
	;Convert sprite Y address to background row address
	lda sprite
	clc
	adc #1	
	and #$F8
	sta R1
	lda #0
	Sta R2
	jsr shift16_left_acc
	jsr shift16_left_acc
	lda #>game_map
	sta R4
	lda #<game_map
	sta R3
	jsr add16_acc
	lda R1
	sta R3
	lda R2
	sta R4

;	;Add the sprite x address to the row address
	lda sprite + 3
	sta R1
	lda #0
	sta R2
	jsr shift16_right_acc
	jsr shift16_right_acc
	jsr shift16_right_acc
	jsr add16_acc 

	ldy #0

	lda tile_color	
	sta (R1), Y
	rts
	


.segment "ZEROPAGE"
x_pos: .res 1
y_pos: .res 1
window: .res 18
windowMaxR0: .res 2
windowMaxR1: .res 2
windowMaxR2: .res 2
; [959 928 929]  [928 929 930]     [958 959 928]
; [31  0   1  ]  [0   1   2  ] ... [30  31  0  ] 
; [63  32  33 ]  [32  34  34 ]     [62  63  32 ]
; 
; [31  0   1  ]  [0   1   2  ]     [30  31  0  ]
; [63  32  33 ]  [32  33  34 ] ... [62  63  32 ]
; [95  64  65 ]  [64  65  66 ]     [94  95  64 ]
; 
; [63  32  33 ]  
; [95  64  65 ]
; [127 96  97 ]
; ...
; 
; [927 896 897]  [896 897 898]     [926 927 896]
; [959 928 929]  [928 929 930] ... [958 959 928]
; [31  0   1  ]  [0   1   2  ]     [30  31  0  ]
.segment "RESET"

;Initial values for the window array
window_vals:
	.word 959, 928, 929
	.word 31,  0,   1
	.word 63,  32,  33
;Load the initial value into window in ZP
initWindow:
	ldy #0
	lda #<window_vals
	sta R1
	lda #>window_vals
	sta R2
@initLoop:
	clc
	lda (R1), Y
	adc #<game_map
	sta window, Y
	iny
	lda (R1), Y
	adc #>game_map
	sta window, Y
	iny
	cpy #18
	bne @initLoop
	
	;Also load maximum values for each row
	;Thses values will be used to compute overflow and wraparound
	jsr updateWindowMaximums
	rts



updateWindowMaximums:	
	clc
	lda window
	adc #1
	sta windowMaxR0
	lda window + 1
	adc #0
	sta windowMaxR0 + 1
	clc
	lda window + (2 * 3)
	adc #1
	sta windowMaxR1
	lda window + (2 * 3) + 1
	adc #0
	sta windowMaxR1 + 1
	clc
	lda window + (2 * 6)
	adc #1
	sta windowMaxR2
	lda window + (2 * 6) + 1
	adc #0
	sta windowMaxR2 + 1
	rts


;Move the window 1 space to the left by incrementing all of it's values
;If a max value is exceeded for the row, wraparound
slideWindow:
	;Start with Row 1, Column 1 (Index 4)
	;If it overflows, the window will advance to the next row
	; which changes everything
	inc window + (2 * 4)
	bne @noOvf11
	inc window + (2 * 4) + 1
@noOvf11:
	lda window + (2 * 4)
	cmp windowMaxR1
	bne @noWrap11
	lda window + (2 * 4) + 1
	cmp windowMaxR1 + 1
	bne @noWrap11
	;Bring the window all the way back to the left, and down 1 row
	;If overflowing down the bottom, X will be set to 1 which will
	;trigger the end of the loop
	jsr returnWindow
	rts

@noWrap11:

	;Increment Row 0 Column 0
	inc window
	bne @noOvf00
	inc window + 1
@noOvf00:
	lda window
	cmp windowMaxR0
	bne @noWrap00
	lda window + 1
	cmp windowMaxR0 + 1
	bne @noWrap00
	sec     ;Subtract 32 in the event of a wraparound
	lda window
	sbc #32
	sta window
	lda window + 1
	sbc #0
	sta window + 1
@noWrap00:

	;Increment Row 0 Column 1
	inc window + (2 * 1)
	bne @noOvf01
	inc window + (2 * 1)  + 1
@noOvf01:
	
	;Increment Row 0 Column 2
	inc window + (2 * 2)
	bne @noOvf02
	inc window + (2 * 2) + 1
@noOvf02:
	lda window + (2 * 2)
	cmp windowMaxR0
	bne @noWrap02
	lda window + (2 * 2) + 1
	cmp windowMaxR0 + 1
	bne @noWrap02
	sec
	lda window + (2 * 2)
	sbc #32
	sta window + (2 * 2)
	lda window + (2 * 2) + 1
	sbc #0
	sta window + (2 * 2) + 1
@noWrap02:
	
	;Increment Row 1 Column 0
	inc window + (2 * 3)
	bne @noOvf10
	inc window + (2 * 3) + 1
@noOvf10:
	lda window + (2 * 3)
	cmp windowMaxR1
	bne @noWrap10
	lda window + (2 * 3) + 1
	cmp windowMaxR1 + 1
	bne @noWrap10
	sec
	lda window + (2 * 3)
	sbc #32
	sta window + (2 * 3)
	lda window + (2 * 3) + 1
	sbc #0
	sta window + (2 * 3) + 1
@noWrap10:	

	;Increment Row 1 Column 2
	inc window + (2 * 5)
	bne @noOvf12
	inc window + (2 * 5) + 1
@noOvf12:
	lda window + (2 * 5)
	cmp windowMaxR1
	bne @noWrap12
	lda window + (2 * 5) + 1
	cmp windowMaxR1 + 1
	bne @noWrap12
	sec
	lda window + (2 * 5)
	sbc #32
	sta window + (2 * 5)
	lda window + (2 * 5) + 1
	sbc #0
	sta window + (2 * 5) + 1
@noWrap12:

	;Increment Row 2 Column 0
	inc window + (2 * 6)
	bne @noOvf20
	inc window + (2 * 6) + 1
@noOvf20:
	lda window + (2 * 6)
	cmp windowMaxR2
	bne @noWrap20
	lda window + (2 * 6) + 1
	cmp windowMaxR2 + 1
	bne @noWrap20
	sec
	lda window + (2 * 6)
	sbc #32
	sta window + (2 * 6)
	lda window + (2 * 6) + 1
	sbc #0
	sta window + (2 * 6) + 1
@noWrap20:

	;Increment Row 2 Column 1
	inc window + (2 * 7)
	bne @noOvf21
	inc window + (2 * 7) + 1
@noOvf21:

	;Increment Row 2 Column 2
	inc window + (2 * 8)
	bne @noOvf22
	inc window + (2 * 8) + 1
@noOvf22:
	lda window + (2 * 8)
	cmp windowMaxR2
	bne @noWrap22
	lda window + (2 * 8) + 1
	cmp windowMaxR2 + 1
	bne @noWrap22
	sec
	lda window + (2 * 8)
	sbc #32
	sta window + (2 * 8)
	lda window + (2 * 8) + 1
	sbc #0
	sta window + (2 * 8) + 1
@noWrap22:

	rts


;Send the window back to the first column, one row down
returnWindow:
	;Special case: If the center tile hit the bottom you're done
	lda window + (2 * 4)
	cmp #<(960 + game_map)
	bne @notDone
	lda window + (2 * 4) + 1
	cmp #>(960 + game_map)
	bne @notDone
	ldx #1    ;Setting X will trigger the end of the slide loop
	rts
@notDone:

	;Another Special case: Row 0 can wrap to the bottom
	lda window
	cmp #<(958 + game_map) 
	bne @notWrapped
	lda window + 1
	cmp #>(958 + game_map)
	bne @notWrapped
	lda #<(31 + game_map)
	sta window
	lda #<game_map
	sta window + (2 * 1)
	lda #<(1 + game_map)
	sta window + (2 * 2)
	lda #>game_map
	sta window + 1
	sta window + (2 * 1) + 1
	sta window + (2 * 2) + 1
	jmp @returnRow1
@notWrapped:


	;Add 33 to Row 0 Column 0
	clc
	lda window
	adc #33
	sta window
	lda window + 1
	adc #0
	sta window + 1

	;Increment Row 0 Column 1
	inc window + (2 * 1)
	bne @noOvf01
	inc window + (2 * 1) + 1
@noOvf01:
	
	;Add 33 to Row 0 Column 2
	clc
	lda window + (2 * 2)
	adc #33
	sta window + (2 * 2)
	lda window + (2 * 2) + 1
	adc #0
	sta window + (2 * 2) + 1

@returnRow1:
	;Add 33 to Row 1 Column 1
	clc
	lda window + (2 * 3)
	adc #33
	sta window + (2 * 3)
	lda window + (2 * 3) + 1
	adc #0
	sta window + (2 * 3) + 1

	;No need to touch Row 1 Column 1
	;It was incremented before the call to this routine

	;Add 33 to Row 1 Column 2
	clc
	lda window + (2 * 5)
	adc #33
	sta window + (2 * 5)
	lda window + (2 * 5) + 1
	adc #0
	sta window + (2 * 5) + 1

	;And an additional special case: Row 2 wraps to the top
	lda window + (2 * 6)
	cmp #<(958 + game_map)
	bne @noTopWrap
	lda window + (2 * 6) + 1
	cmp #>(958 + game_map)
	bne @noTopWrap
	lda #<(31 + game_map)
	sta window + (2 * 6)
	lda #<(game_map)
	sta window + (2 * 7)
	lda #<(game_map + 1)
	sta window + (2 * 8)
	lda #>(game_map)
	sta window + (2 * 6) + 1
	sta window + (2 * 7) + 1
	sta window + (2 * 8) + 1
	jsr updateWindowMaximums
	rts
@noTopWrap:

	;Add 33 to Row 2 Column 0
	clc
	lda window + (2 * 6)
	adc #33
	sta window + (2 * 6)
	lda window + (2 * 6) + 1
	adc #0
	sta window + (2 * 6) + 1

	;Increment Row 2 Column 1
	inc window + (2 * 7)
	bne @noOvf21
	inc window + (2 * 7) + 1
@noOvf21:
	
	;Add 33 to Row 2 Column 2
	clc
	lda window + (2 * 8)
	adc #33
	sta window + (2 * 8)
	lda window + (2 * 8) + 1
	adc #0
	adc window + (2 * 8) + 1

	jsr updateWindowMaximums	
	rts


;Add together the values of the 8 tiles around the window
; The center tile doesn't count
;Return the sum in R1
tallyWindow:
	clc
	lda (window), Y
	and #$FE
	sta R1
	lda (window + (2 * 1)), Y
	and #$FE
	adc R1
	sta R1
	lda (window + (2 * 2)), Y
	and #$FE
	adc R1
	sta R1
	lda (window + (2 * 3)), Y
	and #$FE
	adc R1
	sta R1
	lda (window + (2 * 5)), Y
	and #$FE
	adc R1
	sta R1
	lda (window + (2 * 6)), Y
	and #$FE
	adc R1
	sta R1
	lda (window + (2 * 7)), Y
	and #$FE
	adc R1
	sta R1
	rts



lifeExecute:
	jsr initWindow
	lda $2002
@execute_loop:
	ldx #0
	jsr slideWindow    ;Be careful not to touch X until done tallying
;	ldy #0
;	jsr tally_window
;	lda R1
;	cmp #2
;	beq @execute_loop:
;	cmp #3
;	bne @tile_dies
;
;	lda #1
;	sta (window + (2 * 4)), Y
;	jmp execute_loop
;	lda #0
;	sta (window + (2 * 4)), Y

	txa    ;slide_window returns X != 0 if the window center overflows
	beq @execute_loop	
	lda $2002
	rts



;life_execute:
;	lda #0
;	sta R8
;	sta R3
;	sta R4
;	sta x_pos
;	sta y_pos
;	tay
;	tax
;
;	lda #<game_map
;	sta R5
;	lda #>game_map
;	sta R6
;
;@countingLoop:
;	lda #0
;	sta R8
;
;	jsr addRightNeighbour
;	jsr addLowerRightNeighbour
;	jsr addLowerNeighbour
;	jsr addLowerLeftNeighbour
;	jsr addLeftNeighbour
;	jsr addUpperLeftNeighbour
;	jsr addUpperNeighbour
;	jsr addUpperRightNeighbour
;
;	cmp #2
;	beq @cellSurvives
;	cmp #3
;	beq @cellLives
;	lda #0
;	jmp @storeCell
;@cellSurvives:
;	lda (R5), Y
;	jmp @storeCell
;@cellLives:
;	lda #1
;@storeCell:
;	asl
;	ora (R5), Y
;	sta (R5), Y
;@incrementPointer:
;	inc R5
;	bne @incrementXPos
;	inc R6
;
;@incrementXPos:
;	clc
;	lda x_pos
;	adc #8
;	sta x_pos
;	cmp #32
;	bne @checkCondition
;	lda #0
;	sta x_pos
;	lda #8
;	adc y_pos
;	sta y_pos
;
;@checkCondition:
;	lda R5
;	cmp #<(game_map + 960)
;	bne @countingLoop
;	lda R6
;	cmp #>(game_map + 960)
;	bne @countingLoop
;
;	lda #<game_map
;	sta R5
;	lda #>game_map
;	sta R6
;	ldy #0
;@shiftLoop:
;	lda (R5), Y
;	lsr
;	sta (R5), Y
;	iny
;	bne @shiftLoopCond
;	inc R6
;@shiftLoopCond:
;	cpy #<(game_map + 960)
;	bne @shiftLoop
;	lda R6
;	cmp #>(game_map + 960)
;	bne @shiftLoop
;
;	rts


addRightNeighbour:
	lda R5
	sta R1
	lda R6
	sta R2
	lda x_pos
	sta R3
	jsr findRightNeighbour
	lda (R1), Y
	and #$01
	clc
	adc R8
	sta R8
	rts		

addLowerRightNeighbour:
	lda R5
	sta R1
	lda R6
	sta R2
	lda x_pos
	sta R3
	lda y_pos
	sta R4
	jsr findLowerRightNeighbour
	lda (R1), Y
	and #$01
	clc
	adc R8
	sta R8
	rts		
	
addLowerNeighbour:
	lda R5
	sta R1
	lda R6
	sta R2
	lda y_pos
	sta R3	
	jsr findLowerNeighbour
	lda (R1), Y
	and #$01
	clc
	adc R8
	sta R8
	rts		
	
addLowerLeftNeighbour:
	lda R5
	sta R1
	lda R6
	sta R2
	lda x_pos
	sta R3
	lda y_pos
	sta R4
	jsr findLowerLeftNeighbour
	lda (R1), Y
	and #$01
	clc
	adc R8
	sta R8
	rts		
	
addLeftNeighbour:
	lda R5
	sta R1
	lda R6
	sta R2
	lda x_pos
	sta R3
	jsr findLeftNeighbour
	lda (R1), Y
	and #$01
	clc
	adc R8
	sta R8
	rts		
	
addUpperLeftNeighbour:
	lda R5
	sta R1
	lda R6
	sta R2
	lda x_pos
	sta R3
	lda y_pos
	sta R4
	jsr findUpperLeftNeighbour
	lda (R1), Y
	and #$01
	clc
	adc R8
	sta R8
	rts		
	
addUpperNeighbour:
	lda R5
	sta R1
	lda R6
	sta R2
	lda y_pos
	sta R4
	jsr findUpperNeighbour
	lda (R1), Y
	and #$01
	clc
	adc R8
	sta R8
	rts		
	
addUpperRightNeighbour:
	lda R5
	sta R1
	lda R6
	sta R2
	lda x_pos
	sta R3
	lda y_pos
	sta R4
	jsr findUpperRightNeighbour
	lda (R1), Y
	and #$01
	clc
	adc R8
	sta R8
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
	cmp #231
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
	
;	lda #2
;	sta R5
;	clc
;	lda #>960
;	adc #>game_map
;	sta R2
;	lda #<game_map
;	sta R1
;	ldy #<960
;@updateLoop:
;	dey
;	lda R5
;	cmp #4
;	bne @noColorOverflow
;	lda #0
;	sta R5
;@noColorOverflow:
;	sta (R1), Y	
;	inc R5
;	cpy #0
;	bne @updateLoop
;	dec R2
;	lda R2
;	cmp #(>game_map) - 1
;	bne @updateLoop
	
	rts


paintBackground:
	lda update_ack
	beq @pendingAck
	rts
@pendingAck:
	;Add map_offset to game_map 
	clc
	lda map_offset
	adc #<(game_map)
	sta R1
	lda map_offset + 1
	adc #>(game_map)
	sta R2

	lda #<nt_buffer
	sta R3
	lda #>nt_buffer
	sta R4
	
	ldy #(POP_SLIDE_COUNT)
@pushLoop:
	dey
	lda (R1), Y
	sta (R3), Y
	cpy #0
	bne @pushLoop
	
	lda #1
	sta update_request
	rts

updateOffsets:
	lda update_ack
	bne @noUpdateAck
	rts
@noUpdateAck:
	lda update_request
	beq @pendingRequest
	rts
@pendingRequest:
	;Increment map_offset in POP_SLIDE_COUNT byte chunks until it's > 960
	lda map_offset
	sta R1
	lda map_offset + 1
	sta R2
	lda #<(960 - POP_SLIDE_COUNT)
	sta R3
	lda #>(960 - POP_SLIDE_COUNT)
	sta R4
	jsr is_greater16
	bne @noOffsetReset

	lda #0
	sta map_offset
	sta map_offset + 1
	sta tile_addr
	lda #$20
	sta tile_addr + 1
	lda #0
	sta update_ack
	rts

@noOffsetReset:
	lda #<POP_SLIDE_COUNT
	sta R3
	lda #>POP_SLIDE_COUNT
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
	lda #0
	sta update_ack
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
		
	
