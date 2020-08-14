PROJECT = graphics

SOURCES = ./
COMPONENTS = ./
INCLUDES = ./
BUILD = ./build
L_FLAGS := -Ln $(BUILD)/labels.txt --config linker.cfg
#L_FLAGS := -Ln $(BUILD)/labels.txt --config nrom.cfg
C_FLAGS := -Oirs --add-source
A_FLAGS := -g
LIBS := nes.lib
OBJECTS = $(BUILD)/graphics.o $(BUILD)/background.o $(BUILD)/palette.o $(BUILD)/sprites.o
COMPILE = cc65
ASSEMBLE = ca65
LINK = ld65

.PHONY: all clean
all: $(BUILD) $(BUILD)/$(COMPONENTS) $(PROJECT).nes

$(SOURCES)/%.s: $(SOURCES)/%.c
	$(COMPILE) $(C_FLAGS) --include-dir $(INCLUDES) -o $@ $<

$(BUILD)/$(COMPONENTS)/%.o: $(COMPONENTS)/%.s
	$(ASSEMBLE) -o $@ $<

$(BUILD)/%.o: $(SOURCES)/%.s
	$(ASSEMBLE) $(A_FLAGS) -o $@ $<

$(PROJECT).nes: $(OBJECTS)
	$(LINK) $(L_FLAGS) -o $@ $^ $(LIBS)


clean:
	rm $(BUILD)/*

$(BUILD):
	mkdir $(BUILD)

$(BUILD)/$(COMPONENTS):
	mkdir $(BUILD)/$(COMPONENTS)

