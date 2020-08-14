#include "neslib.h"

typedef enum {
	PALLETTE_BLACK = 0x0F,
	PALLETTE_DGRAY = 0x00,
	PALLETTE_LGRAY = 0x10,
	PALLETTE_WHITE = 0x30
} pallette_e;

#pragma bss-name(push, "ZEROPAGE")

unsigned char index;
unsigned char const text[] = "Hello World!";
unsigned char const pallette[] = {
	PALLETTE_BLACK, PALLETTE_DGRAY, PALLETTE_LGRAY, PALLETTE_WHITE,
	0,0,0,0,
	0,0,0,0,
	0,0,0,0
};


void main(void)
{
	ppu_off();
	pal_bg(pallette);
	vram_adr(NTADR_A(10,14));
	
	for(index = 0; text[index]; index++)
	{
		vram_put(text[index]);
	}

	ppu_on_all();

	for(;;);
}

 
