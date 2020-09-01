.ifndef ZP_REG_INC
.define ZP_REG_INC = 1

;Simply doing import for symbols in the zeropage is insufficient.
;That's why importzp is a thing.
.importzp R1, R2, R3, R4, R5, R6, R7, R8

.endif ;ZP_REG_INC
