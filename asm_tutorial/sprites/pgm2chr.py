

f = open("sprite_sheet.pgm", "rb")
pgm = f.read()
f.close()

comment_start = pgm.index(ord('#'))
comment_end = pgm.index(ord('\n'), comment_start + 1)
x_size_end = pgm.index(ord(' '), comment_end + 1)
y_size_end = pgm.index(ord('\n'), x_size_end + 1)
max_byte_end = pgm.index(ord('\n'), y_size_end + 1)

x_size = int(''.join(chr(i) for i in pgm[comment_end + 1 : x_size_end]))
y_size = int(''.join(chr(i) for i in pgm[x_size_end + 1 : y_size_end]))
max_byte = int(''.join(chr(i) for i in pgm[y_size_end + 1 : max_byte_end]))

print(x_size)
print(y_size)
print(max_byte)

img = list(pgm[max_byte_end + 1 :])

num_of_y_tiles = int(y_size / 8)
num_of_x_tiles = int(x_size / 8)

neschr = bytearray([0] * int(x_size * y_size / 2))
c_idx = 0
bit0 = bytearray([0, 1, 0, 1])
bit1 = bytearray([0, 0, 1, 1])

for y_tile in range(0, num_of_y_tiles):
    for x_tile in range(0, num_of_x_tiles):
        tile_idx = (8 * x_tile) + (64 * num_of_x_tiles * y_tile)
        tile_pal = []

        #Populate the tile palette by assigning each color to a value form 0-3 
        for y in range(0, 8):
            for x in range(0, 8):
                idx = (x + (x_size * y)) + tile_idx
                val = img[idx]
                try:
                    color = tile_pal.index(val)
                except ValueError:
                    tile_pal.append(val)
                    if len(tile_pal) > 4:
                        raise Exception("Too many colors in tile ({}, {})".format(x_tile, y_tile))
                    tile_pal.sort()
        print(tile_pal)
        for y in range(0, 8):
            for x in range(0, 8):
                idx = (x + (x_size * y)) + tile_idx
                color = tile_pal.index(img[idx])
                neschr[c_idx] |= bit0[color] << (7 - x)
                neschr[c_idx + 8] |= bit1[color] << (7 - x)
            c_idx += 1           
#            print("{} {}".format(c_idx, neschr[c_idx]))
#            c_idx += (((y % 2 and not 0) * 4) - 1) #Clever trick to swap endianness
        c_idx += 8


#for idx in range(0, 8):
#    print(neschr[idx * 16 : 16 + (16 * idx)]) 
out = open("sprite_sheet.chr", "wb")
out.write(neschr)
out.close()

#I could go on with this for days and days
# One thing that would be nice would be a way to flatten the color palettes for the entire image
# and make certain that like colors are represented by the same color index
# Also the thing should be made into a real command line utility with inputs and outputs 
# passed as command line arguments
# And some unit testing would be nice
