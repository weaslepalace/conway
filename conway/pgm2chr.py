#!/usr/bin/python3
import sys
import getopt


class Pgm2Chr:

    in_file = ""
    out_file = ""

    def __init__(self, ifile, ofile):
        self.in_file = ifile
        self.out_file = ofile


    def read_in_file(self):
        f = open(self.in_file, "rb")
        pgm = f.read()
        f.close()
        return pgm        


    def parse_header(self, pgm):    
        #The comment section of a .pgm file starts with a '#'
        #   It appears that there is only one commet section per file
        comment_start = pgm.index(ord('#'))
        comment_end = pgm.index(ord('\n'), comment_start + 1)
        x_size_end = pgm.index(ord(' '), comment_end + 1)
        y_size_end = pgm.index(ord('\n'), x_size_end + 1)
        max_byte_end = pgm.index(ord('\n'), y_size_end + 1)
    
        x_size = int(''.join(chr(i) for i in pgm[comment_end + 1 : x_size_end]))
        y_size = int(''.join(chr(i) for i in pgm[x_size_end + 1 : y_size_end]))
        max_byte = int(''.join(chr(i) for i in pgm[y_size_end + 1 : max_byte_end]))

        img = list(pgm[max_byte_end + 1 :])

        return img, x_size, y_size


    def chr_loop(self, img, x_size, y_size):
        num_of_y_tiles = int(y_size / 8)
        num_of_x_tiles = int(x_size / 8)
        
        neschr = bytearray([0] * int(x_size * y_size / 2))
        c_idx = 0
        bit0 = bytearray([0, 1, 0, 1])
        bit1 = bytearray([0, 0, 1, 1])
        tile_pal = []

        for y_tile in range(0, num_of_y_tiles):
            for x_tile in range(0, num_of_x_tiles):
                tile_idx = (8 * x_tile) + (64 * num_of_x_tiles * y_tile)
        
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
                for y in range(0, 8):
                    for x in range(0, 8):
                        idx = (x + (x_size * y)) + tile_idx
                        color = tile_pal.index(img[idx])
                        neschr[c_idx] |= bit0[color] << (7 - x)
                        neschr[c_idx + 8] |= bit1[color] << (7 - x)
                    c_idx += 1           
                c_idx += 8
        return neschr    


    def write_out_file(self, chr_data):
        out = open(self.out_file, "wb")
        out.write(chr_data)
        out.close()


    def execute(self):
        pgm_data = self.read_in_file()
        img, x_size, y_size = self.parse_header(pgm_data)
        chr_data = self.chr_loop(img, x_size, y_size)
        self.write_out_file(chr_data)


#I could go on with this for days and days
# One thing that would be nice would be a way to flatten the color palettes for the entire image
# and make certain that like colors are represented by the same color index
# And some unit testing would be nice
def usage():
    print("pgm2chr.py -i <input_file> -o <output_file>")
    sys.exit(-1)

def get_args(argv):
    ifile = ""
    ofile = ""
    try:
        opts, args = getopt.getopt(argv, "hi:o:", ["input=", "output="])
    except:
        print("Invalid arguments")
        usage()
    for opt, arg in opts:
        if opt in ("-i", "--input"):
            ifile = arg
        elif opt in ("-o", "--output"):
            ofile = arg
        elif opt == "-h":
            usage()
    if ifile == "" or ofile == "":
        usage()
 
    return ifile, ofile


if __name__ == "__main__":
    ifile, ofile = get_args(sys.argv[1:])
    p2c = Pgm2Chr(ifile, ofile)
    p2c.execute()

