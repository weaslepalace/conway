#include "neslib.h"
#include "nesdoug.h"

typedef enum {
	PALETTE_BLACK = 0x0F,
	PALETTE_DGRAY = 0x00,
	PALETTE_LGRAY = 0x10,
	PALETTE_WHITE = 0x30
} palette_e;

unsigned char const palette[] = {
	PALETTE_BLACK, PALETTE_DGRAY, PALETTE_LGRAY, PALETTE_WHITE,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0
};

unsigned char sequential_text[] = {
	MSB(NTADR_A(1, 1)) | NT_UPD_HORZ,
	LSB(NTADR_A(1, 1)),
	12,
	'H', 'E', 'L', 'L', 'O', ' ', 'W', 'O', 'R', 'L', 'D', '!',
	NT_UPD_EOF
};

unsigned char const non_sequential_text[] = {
	MSB(NTADR_A(18, 5)),	//NTADR_A(8, 17) is some sort of address,
	LSB(NTADR_A(18, 5)),	//	but for what exactly?
	'A',					//	Could it be the coordinates on the screen?
	MSB(NTADR_A(8, 17)),
	LSB(NTADR_B(8, 17)),
	'B',
	NT_UPD_EOF
};


void main(void)
{
	//This function turns the screen off. Don't know why we'd to that.
	//	Maybe it needs to be off before the palette can be set.
	ppu_off();

	//Sends the palette info to the ppu.
	//	Do more reading to find out what that means.
	pal_bg(palette);

	//Turn the screen back on. Now, what do they mean by screen. 
	//	It seems like the screen is going to scan no matter what.
	ppu_on_all();

	//This loads "HELLO WORLD!" to a buffer to be moved to the PPU
	//	during the v-blank period. V-blank is the time between frames
	//	where the PPU can be updated without corruption
	set_vram_update(sequential_text);

	//Wait for the v-blank period to begin. During v-blank, the contents
	//	of the buffer will be moved to the PPU automatically.
	ppu_wait_nmi();

	//Load an 'A' and 'B' into the buffer. 
	set_vram_update(non_sequential_text);
	
	//Wait for v-blank again to flush the buffer
	ppu_wait_nmi();

	//Let's see what that NT_UPD_HORZ bit does
//	sequential_text[0] &= ~NT_UPD_HORZ; //I don't know, but it's weird
//	set_vram_update(sequential_text);
//	ppu_wait_nmi(); 

	//I then after we write to the PPU, it keeps writing with every v-blank cycle
	//So this makes sure it stops writing after we're done writing.
	set_vram_update(NULL);

	for(;;);
}

