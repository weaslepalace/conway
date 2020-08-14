PROJECT = hello2

SOURCES = ./
COMPONENTS = ./components
INCLUDES = ./components/LIB/
BUILD = ./build
L_FLAGS := -C nrom_32k_vert.cfg -Ln $(BUILD)/labels.txt
C_FLAGS := -Oirs --add-source
A_FLAGS := -g
LIBS := nes.lib
OBJECTS = $(BUILD)/hello2.o $(BUILD)/$(COMPONENTS)/crt0.o
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

