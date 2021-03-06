#include <powernex/cpu/gdt.h>

extern void gdt_flush(gdt_ptr_t * ptr);
static void gdt_setGate(int32_t num, uint32_t base, uint32_t limit, uint8_t access, uint8_t gran);

gdt_entry_t gdt_entries[3];
gdt_ptr_t gdt_ptr;

void gdt_init() {
	gdt_ptr.limit = sizeof(gdt_entry_t) * 3 - 1;
	gdt_ptr.base = (uint32_t) &gdt_entries;

	gdt_setGate(0, 0, 0, 				0,		0   );
	gdt_setGate(1, 0, 0xFFFFF, 	0x9A, 0xCF);
	gdt_setGate(2, 0, 0xFFFFF,	0x92, 0xCF);

	gdt_flush(&gdt_ptr);
}

static void gdt_setGate(int32_t num, uint32_t base, uint32_t limit, uint8_t access, uint8_t gran){
    gdt_entries[num].base_low    = (base & 0xFFFF);
    gdt_entries[num].base_middle = (base >> 16) & 0xFF;
    gdt_entries[num].base_high   = (base >> 24) & 0xFF;

    gdt_entries[num].limit_low   = (limit & 0xFFFF);
    gdt_entries[num].granularity = (limit >> 16) & 0x0F;
    
    gdt_entries[num].granularity |= gran & 0xF0;
    gdt_entries[num].access      = access;
}
