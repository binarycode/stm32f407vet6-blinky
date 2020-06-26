PROJECT = blinky

BUILD_DIR = bin
SRC_DIR   = src

CFILES = $(SRC_DIR)/blinky.c

PREFIX  = arm-none-eabi-
CC      = $(PREFIX)gcc
LD      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump
OOCD    = openocd

OPT = -Os

# from `$(OPENCM3_DIR)/scripts/genlink.py $(OPENCM3_DIR)/ld/devices.data $(OPENCM3_DEVICE) CPU`
ARCH_FLAGS += -mcpu=cortex-m4
ARCH_FLAGS += -mthumb
# from `$(OPENCM3_DIR)/scripts/genlink.py $(OPENCM3_DIR)/ld/devices.data $(OPENCM3_DEVICE) FPU`
ARCH_FLAGS += -mfloat-abi=hard
ARCH_FLAGS += -mfpu=fpv4-sp-d16

# OpenOCD configuration
OOCD_INTERFACE = stlink-v2
OOCD_TARGET    = stm32f4x

# FreeRTOS configuration
FREERTOS_DIR      = freertos
FREERTOS_PORT_DIR = $(FREERTOS_DIR)/portable/GCC/ARM_CM4F
FREERTOS_HEAP_DIR = $(FREERTOS_DIR)/portable/MemMang
FREERTOS_CFILES   += $(wildcard $(FREERTOS_DIR)/*.c)
FREERTOS_CFILES   += $(wildcard $(FREERTOS_PORT_DIR)/*.c)
FREERTOS_CFILES   += $(FREERTOS_HEAP_DIR)/heap_4.c

# LibOpenCM3 configuration
OPENCM3_DIR    = libopencm3
OPENCM3_DEVICE = stm32f407vet6
# from $(OPENCM3_DIR)/scripts/genlink.py $(OPENCM3_DIR)/ld/devices.data $(OPENCM3_DEVICE) FAMILY
# from $(OPENCM3_DIR)/scripts/genlink.py $(OPENCM3_DIR)/ld/devices.data $(OPENCM3_DEVICE) SUBFAMILY
OPENCM3_LIBNAME = opencm3_stm32f4
# from $(OPENCM3_DIR)/scripts/genlink.py $(OPENCM3_DIR)/ld/devices.data $(OPENCM3_DEVICE) DEFS
OPENCM3_DEFS += -DSTM32F4
OPENCM3_DEFS += -DSTM32F4CCM
OPENCM3_DEFS += -DSTM32F407VET6
OPENCM3_DEFS += -D_ROM=512K
OPENCM3_DEFS += -D_RAM=128K
OPENCM3_DEFS += -D_CCM=64K
OPENCM3_DEFS += -D_CCM_OFF=0x10000000
OPENCM3_DEFS += -D_ROM_OFF=0x08000000
OPENCM3_DEFS += -D_RAM_OFF=0x20000000

LDSCRIPT = $(BUILD_DIR)/generated.$(OPENCM3_DEVICE).ld

CFLAGS += $(OPT)
CFLAGS += $(ARCH_FLAGS)
CFLAGS += -std=c99
CFLAGS += -ggdb3 # TODO: check size overhead
CFLAGS += -fno-common
CFLAGS += -ffunction-sections -fdata-sections
CFLAGS += -Wextra -Wshadow -Wno-unused-variable -Wimplicit-function-declaration
CFLAGS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes

CPPFLAGS += -MD # TODO: check generated .d files
CPPFLAGS += -Wall -Wundef
CPPFLAGS += -I$(SRC_DIR)
CPPFLAGS += -I$(OPENCM3_DIR)/include
CPPFLAGS += -I$(FREERTOS_DIR)/include
CPPFLAGS += -I$(FREERTOS_PORT_DIR)
CPPFLAGS += -I$(FREERTOS_HEAP_DIR)
CPPFLAGS += $(OPENCM3_DEFS)

LDFLAGS += $(ARCH_FLAGS)
LDFLAGS += -T$(LDSCRIPT)
LDFLAGS += -L$(OPENCM3_DIR)/lib
LDFLAGS += -nostartfiles
LDFLAGS += -Wl,--gc-sections
ifeq ($(V),99)
LDFLAGS += -Wl,--print-gc-sections
endif

LDLIBS += -specs=nosys.specs
LDLIBS += -Wl,--start-group -lc -lgcc -lnosys -Wl,--end-group
LDLIBS += -l$(OPENCM3_LIBNAME)

OBJS += $(CFILES:.c=.o)
OBJS += $(FREERTOS_CFILES:.c=.o)

# Be silent per default, but 'make V=1' will show all compiler calls.
# If you're insane, V=99 will print out all sorts of things.
V?=0
ifeq ($(V),0)
Q    := @
NULL := 2>/dev/null
endif

.PHONY: all
all: $(BUILD_DIR)/$(PROJECT).elf

.PHONY: flash
flash: $(BUILD_DIR)/$(PROJECT).elf
	$(Q)(echo "halt; program $(realpath $(*).elf) verify reset" | nc -4 localhost 4444 2>/dev/null) || \
		$(OOCD) -f interface/$(OOCD_INTERFACE).cfg \
		-f target/$(OOCD_TARGET).cfg \
		-c "program $(realpath $(*).elf) verify reset exit" \
		$(NULL)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)/* \
		$(SRC_DIR)/*.o $(SRC_DIR)/*.d \
		$(FREERTOS_DIR)/*.o $(FREERTOS_DIR)/*.d \
		$(FREERTOS_PORT_DIR)/*.o $(FREERTOS_PORT_DIR)/*.d \
		$(FREERTOS_HEAP_DIR)/*.o $(FREERTOS_HEAP_DIR)/*.d

define opencm3-genlink =
@printf "$(1)\n"
@$(OPENCM3_DIR)/scripts/genlink.py $(OPENCM3_DIR)/ld/devices.data $(OPENCM3_DEVICE) $(1)
@printf "\n\n"
endef

.PHONY: opencm3-device-data
opencm3-device-data:
	$(call opencm3-genlink,FAMILY)
	$(call opencm3-genlink,SUBFAMILY)
	$(call opencm3-genlink,CPU)
	$(call opencm3-genlink,FPU)
	$(call opencm3-genlink,DEFS)
	$(call opencm3-genlink,CPPFLAGS)

$(BUILD_DIR)/$(PROJECT).elf: $(OBJS) $(LDSCRIPT) $(LIBDEPS)
	@printf "  LD      $@\n"
	$(Q)$(LD) $(LDFLAGS) $(OBJS) $(LDLIBS) -o $@

$(LDSCRIPT): $(OPENCM3_DIR)/ld/linker.ld.S $(OPENCM3_DIR)/ld/devices.data
	@printf "  GENLNK  $(OPENCM3_DEVICE)\n"
	$(Q)$(CPP) $(ARCH_FLAGS) $(OPENCM3_DEFS) -P -E $< -o $@

%.o: %.c
	@printf "  CC      $<\n"
	$(Q)$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

-include $(OBJS:.o=.d)
