;Rule's for Conway's Game of Life (according to Wikipedia)
; 1. Any live cell with fewer than two live neighbours dies,
;	 as if by underpopulation
; 2. Any live cell with two or three live neighbours lives on to the
;	 next generation
; 3. Any live cell with more than three live neighbours dies,
;	 as if by overpopulation
; 4. Any dead cell with exactly three live neighbours becomes a live cell,
;	 as if by reproduction

;See life.c for an implementaion in C (for reference only)

.segment "ZEROPAGE"

.define LIFE_X_SIZE 32
.define LIFE_Y_SIZE 30
.define LIFE_WORLD_SIZE LIFE_X_SIZE * LIFE_Y_SIZE

life_world: .res 2
life_new_world: .res 2 
life_world_idx: .res 2
life_x: .res 1
life_y: .res 1
life_live_count: .res 1
life_neighbour: .res 16
.enum
	NEIGHBOUR_LEFT
	NEIGHBOUR_RIGHT
	NEIGHBOUR_UP
	NEIGHBOUR_DN
	NEIGHBOUR_UP_LEFT
	NEIGHBOUR_DN_LEFT
	NEIGHBOUR_UP_RIGHT
	NEIGHBOUR_DN_RIGHT
.endenum



life_execute:
	lda -1
	sta life_y            ;Initialize y to -1
	lda #$00
	sta life_x            ;Initialize x to 0
	sta life_world_idx    ;Initialize world index to 0
@findNeighboursForIdx:
	sta life_live_count   ;Initialize neighbour count to 0

	jsr getInitialNeighbours	
	jsr adjustNeighboursForOverflow

	;Count the live neighbours
	ldx 0          ;Use X as loop count init to zero
@countLoop:
	ldy (life_neighbour), X
	lda (world), Y
	cmp #$01       ;If world[life_neighbour[X]] == 1
	bne @neighbourDead
	inc life_live_count    ;live_count++
@neighbourDead:
	inx
	cpx 8
	bne @countLoop

	;Apply the rule proposed by The Great Dr. Conway
	;1. Die if neighbours < 2, as if by underpopulation
	lda life_live_count
	sbc 2                    ;If live_count < 2
	bmi @notUnderPopulated 

	lda #$00
	ldx life_world_idx
	sta (life_new_world), X    ; new_world[X] = 0
	jmp @prepareNextLoop

@notUnderPopulated:

	;2. Live, but don't grow if neighbours == 2
	lda life_live_count
	cmp 2                    ;If live_count == 2
	bne @notStablePopulation

	ldx life_world_idx
	lda (life_world), X
	sta (life_new_world), X  ; new_world[X] = world[X]
	jmp @prepareNextLoop

@notStablePopulation:

	;3. Grow if neighbours == 3, as if by reporduction
	lda life_live_count
	cmp 3                    ;If live_count == 3
	bne @notGrowingPopulation

	lda #$01
	ldx life_world_idx
	sta (life_new_world), X  ; new_world[X] = 1
	jmp @prapareNextLoop

@notGrowingPopulation:

	;4. Die if neighbours > 3, as if by overpopulation
	lda #$00
	ldx life_world_idx
	sta (life_new_world), X  ; new_world[X] = 0

@prepareNextLoop:
	inc life_x
	inc life_world_idx       ;Increment index low byte
	bne @noOverflow          ;Check if low byte overflows
	inc life_world_idx + 1   ; if so, increment index high byte
@noOverflow 
	lda life_world_idx
	cmp #<LIFE_WORLD_SIZE
	bne @findNeighboursForIdx ;All the way back to the top
	lda life_world_idx + 1  
	cmp #>LiFE_WORLD_SIZE
	bne @findNeighboursForIdx ;All the way back to the top

;End loop
	rts

	
;Compute the location of all eight neighbours
getInitialNeighbours:

	;Find the neighbour to the left of the index
	ldx (life_neighbour_idx)
	ldy (life_neighbour_idx + 1)
	DECRAMENT_16
	stx (life_neighbour + NEIGHBOUR_LEFT)
	sty (life_neighbour + NEIGHBOUR_LEFT + 1)   ;LEFT = idx - 1

	;Find the neighbour to the up-left
	ldx (life_neighbour_idx)
	ldy (life_neighbour_idx + 1)
	SUB_16_IMMEDIATE #LIFE_X_SIZE
	DECRAMENT_16w    ;UP_LEFT = idx - x_size - 1
	stx (life_neighbour + NEIGHBOUR_UP_LEFT)
	sty (life_neighbour + NEIGHBOUR_UP_LEFT + 1)  

	;Find the neighbour in the up direction
	ldx (life_neighbour_idx)
	ldy (life_neighbour_idx + 1)
	SUB_16_IMMEDIATE #LIFE_X_SIZE    ;UP = idx - x_size
	stx (life_neighbour + NEIGHBOUR_UP)
	sty (life_neighbour + NEIGHBOUR_UP + 1)  

	;Find the neighbour to the up-right
	ldx (life_neighbour_idx)
	ldy (life_neighbour_idx + 1)
	SUB_16_IMMEDIATE #LIFE_X_SIZE
	INCREMENT_16    ;UP_RIGHT = idx - x_size + 1
	stx (life_neighbour + NEIGHBOUR_UP_RIGHT)
	sty (life_neighbour + NEIGHBOUR_UP_RIGHT + 1)  

	;Find the neighbour to the right
	ldx (life_neighbour_idx)
	ldy (life_neighbour_idx + 1)
	INCREMENT_16    ;RIGHT = idx + 1
	stx (life_neighbour + NEIGHBOUR_RIGHT)
	sty (life_neighbour + NEIGHBOUR_RIGHT + 1)  

	;Find the neighboyr to the down-right
	ldx (life_neighbour_idx)
	ldy (life_neighbour_idx + 1)
	ADD_16_IMMEDIATE #LIFE_X_SIZE
	INCREMENT_16    ;DOWN_RIGHT = idx + x_size + 1
	stx (life_neighbour + NEIGHBOUR_DOWN_RIGHT)
	sty (life_neighbour + NEIGHBOUR_DOWN_RIGHT + 1)  

	;Find the neighboyr in the down direction
	ldx (life_neighbour_idx)
	ldy (life_neighbour_idx + 1)
	ADD_16_IMMEDIATE #LIFE_X_SIZE    ;DOWN = idx + x_size
	stx (life_neighbour + NEIGHBOUR_DOWN)
	sty (life_neighbour + NEIGHBOUR_DOWN + 1)  

	;Find the neighbour to the down-left
	ldx (life_neighbour_idx)
	ldy (life_neighbour_idx + 1)
	ADD_16_IMMEDIATE #LIFE_X_SIZE    ;DOWN-LEFT = idx + x_size - 1
	DECREMENT_16   
	stx (life_neighbour + NEIGHBOUR_)
	sty (life_neighbour + NEIGHBOUR_ + 1)  

	rts



;Offset the neighbour locations to account for wrap-around
adjustNeighboursForWrapAround:

	;Adjust for wrap-around to the right
	;  This also trigger the x counter to increment
	lda #(LIFE_X_SIZE - 1)
	cmp life_x               ;If x == (LIFE_X_SIZE - 1)
	bne @noRightWrapAround
	lda #$00
	sta life_x               ;	Reset x counter

	;Wrap-around all left neighbours
	; Subtract x_size from all left neighbours
	ldx (life_neighbour + NEIGHBOUR_UP_LEFT)
	ldy (life_neighbour + NEIGHBOUR_UP_LEFT + 1)
	SUB_16_IMMEDIATE #LIFE_X_SIZE
	stx (life_neighbour + NEIGHBOUR_UP_LEFT)
	sty (life_neighbour + NEIGHBOUR_UP_LEFT + 1)
	ldx (life_neighbour + NEIGHBOUR_LEFT)
	ldy (life_neighbour + NEIGHBOUR_LEFT + 1)
	SUB_16_IMMEDIATE #LIFE_X_SIZE
	stx (life_neighbour + NEIGHBOUR_LEFT)
	sty (life_neighbour + NEIGHBOUR_LEFT + 1)
	ldx (life_neighbour + NEIGHBOUR_DN_LEFT)
	ldy (life_neighbour + NEIGHBOUR_DN_LEFT + 1)
	SUB_16_IMMEDIATE #LIFE_X_SIZE
	stx (life_neighbour + NEIGHBOUR_DN_LEFT)
	sty (life_neighbour + NEIGHBOUR_DN_LEFT + 1)
@noRightWrapAround:

	;Adjust for wraparound to the left
	lda #$00
	cmp life_x               ;If x == 0
	bne @noLeftWrapAround:   
	lda life_y
	inc                      ;  y++
	
	;Wrap-around all right neighbours
	; Add x_size to all right neighbours
	ldx (life_neighbour + NEIGHBOUR_UP_RIGHT)
	ldy (life_neighbour + NEIGHBOUR_UP_RIGHT + 1)
	ADD_16_IMMEDIATE #LIFE_X_SIZE
	stx (life_neighbour + NEIGHBOUR_UP_RIGHT)
	sty (life_neighbour + NEIGHBOUR_UP_RIGHT + 1)
	ldx (life_neighbour + NEIGHBOUR_RIGHT)
	ldy (life_neighbour + NEIGHBOUR_RIGHT + 1)
	ADD_16_IMMEDIATE #LIFE_X_SIZE
	stx (life_neighbour + NEIGHBOUR_RIGHT)
	sty (life_neighbour + NEIGHBOUR_RIGHT + 1)
	ldx (life_neighbour + NEIGHBOUR_DN_RIGHT)
	ldy (life_neighbour + NEIGHBOUR_DN_RIGHT + 1)
	ADD_16_IMMEDIATE #LIFE_X_SIZE
	stx (life_neighbour + NEIGHBOUR_DN_RIGHT)
	sty (life_neighbour + NEIGHBOUR_DN_RIGHT + 1)
@noLeftWrapAround:	

	;Adjust for wrap-around in the down direction
	lda #LIFE_Y_SIZE - 1
	cmp life_y               ;If y == (LIFE_Y_SIZE - 1)
	bne @noDownWrapAround
	
	;Wrap-around all down neighbours
	lda life_neighbour + NEIGHBOUR_DN
	sbc #(LIFE_WORLD_SIZE - LIFE_X_SIZE)
	sta life_neighbour + NEIGHBOUR_DN
	lda life_neighbour + NEIGHBOUR_DN_RIGHT
	sbc #(LIFE_WORLD_SIZE - LIFE_X_SIZE)
	sta life_neighbour + NEIGHBOUR_DN_RIGHT
	lda life_neighbour + NEIGHBOUR_DN_LEFT
	sbc #(LIFE_WORLD_SIZE - LIFE_X_SIZE)
	sta life_neighbour + NEIGHBOUR_DN_LEFT

@noDownWrapAround:

	lda #$00
	cmp life_y               ;If y == 0
	bne @yNotUnderflow

	;Wrap-around all up neighbours
	lda life_neighbour + NEIGHBOUR_UP
	sbc #(LIFE_WORLD_SIZE - LIFE_X_SIZE)
	sta life_neighbour + NEIGHBOUR_UP
	lda life_neighbour + NEIGHBOUR_UP_RIGHT
	sbc #(LIFE_WORLD_SIZE - LIFE_X_SIZE)
	sta life_neighbour + NEIGHBOUR_UP_RIGHT
	lda life_neighbour + NEIGHBOUR_UP_LEFT
	sbc #(LIFE_WORLD_SIZE - LIFE_X_SIZE)
	sta life_neighbour + NEIGHBOUR_UP_LEFT
	
	rts



