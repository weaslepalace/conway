;NES assembler tutorial, and maybe boilerplate

.import NES_PRG_BANKS, NES_CHR_BANKS, NES_MAPPER, NES_MIRRORING
.segment "HEADER"
	.byte 'N', 'E', 'S', $1A
	.byte <NES_PRG_BANKS
	.byte <NES_CHR_BANKS
	.byte <NES_MIRRORING
	.byte <NES_MAPPER & $F0
	.res 8, 0

.segment "RESET"
reset:
mainLoop:
	JMP mainLoop

nmi:
	RTI


.segment "VECTORS"
	.word nmi
	.word reset
	.word 0

