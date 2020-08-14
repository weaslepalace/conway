#include "neslib.h"
#include "nesdoug.h"

typedef enum {
	PALETTE_BLACK = 0x0F,
	PALETTE_DGRAY = 0x00,
	PALETTE_LGRAY = 0x10,
	PALETTE_WHITE = 0x30
};
unsigned char const palette[] = {
	PALETTE_BLACK, PALETTE_DGRAY, PALETTE_LGRAY, PALETTE_WHITE,
	0,0,0,0,
	0,0,0,0,
	0,0,0,0
};

unsigned char const hello[] = {
	'H', 'E', 'L', 'L', 'O', ' ', 'W', 'O', 'R', 'L', 'D', '!'
};
unsigned char const letter_a = 'A';
int address;


void main(void)
{
	//Boiler plate stuff
	ppu_on_all();
	pal_bg(palette);
	ppu_wait_nmi();

	//This feels like it's obfucsating some complexity 
	//	without clear documentation. Not the best design.
	//	Looking at the source, it's calling set_vram_update, which is what we
	//	used in the previous tutorial. So I assume it's just...
	//	OK. I know what's happening. It's passing a pointer containing EOF
	//	to set_vram_buffer. The pointer is at 0x700, and is configurable in
	//	crt0.s. I think it's just doing this as an init.
	set_vram_buffer();

	//Init the index of the vram buffer. Could be more clear.
	clear_vram_buffer();

	//Puts an 'A' on the screen at coordinates 2, 3
	one_vram_buffer(letter_a, NTADR_A(2, 3));
	//Puts a 'B' on the screen at coordinates 5, 6
	one_vram_buffer('B', NTADR_A(5, 6));

	//Converts pixel coordinates to time coordinates
	//	What is a name table?
//	address = get_ppu_addr(0, 0x38, 0xc0);
//	//Puts a 'C' at the above coordinates
//	//	Why is an address variable necessary? Is it optimized out?
//	one_vram_buffer('C', address);
	one_vram_buffer('C', get_ppu_addr(0, 0x38, 0xc0));	

	//Write "HELLO WORLD" from left to write with the 'H' at 10,7
	multi_vram_buffer_horz(hello, sizeof hello, NTADR_A(10, 7));
	//Write "HELLO WORLD" from left to write with the 'H' at 12,12
	multi_vram_buffer_horz(hello, sizeof hello, NTADR_A(12, 12));
	//Write "HELLO WORLD" from left to write with the 'H' at 14,17
	multi_vram_buffer_horz(hello, sizeof hello, NTADR_A(14, 17));
	//Write "HELLO WORLD" from top to bottom with the 'H' at 10, 7
	multi_vram_buffer_vert(hello, sizeof hello, NTADR_A(10, 7));
	//Wait for the v-blank to write the contents of the vram buffer
	ppu_wait_nmi();


	//I think this stops the vram buffer from writing to the ppu every v-blank
	clear_vram_buffer();
	
	//I want to see what happens if I overwrite the end of the screen
	multi_vram_buffer_horz(hello, sizeof hello, NTADR_A(21, 1));
	ppu_wait_nmi();
	clear_vram_buffer();

	for(;;);
}


