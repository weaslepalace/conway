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

;Load the background data in background.s and write it to the PPU
.segment "RESET"
reset:
mainLoop:
	JSR loadBackground	
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
	JMP wait

nmi:
	RTI

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
	
	
.segment "VECTORS"
	.word nmi
	.word reset
	.word 0


.segment "GRAPHICS"
	.incbin "test_out.chr"

.segment "BACKGROUND"
background:
	.include "background.s"
