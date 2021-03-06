#include <powernex/powernex.h>
#include <powernex/elf.h>
#include <powernex/multiboot.h>
#include <powernex/io/textmode.h>
#include <powernex/cpu/gdt.h>
#include <powernex/cpu/idt.h>
#include <powernex/cpu/pit.h>
#include <powernex/cpu/task.h>
#include <powernex/io/port.h>
#include <powernex/io/keyboard.h>
#include <powernex/mem/heap.h>
#include <powernex/mem/paging.h>
#include <powernex/fs/fs.h>
#include <powernex/fs/initrd.h>
#include <powernex/string.h>
#include <powernex/cli.h>
#include <stdarg.h>

static void step(const char * msg, ...);
static void setup(multiboot_info_t * multiboot);

int kmain(UNUSED int multiboot_magic, multiboot_info_t * multiboot) {
	setup(multiboot);
	kputc('\n');
	
	cli_start();
	return 0xDEADBEEF;
}

static void step(const char * str, ...) {
	kputc('[');
	kputcolor(makecolor(COLOR_MAGENTA, COLOR_BLACK));
	kputc('*');
	kputcolor(DEFAULT_COLOR);
	kputc(']');
	kputc(' ');
	va_list va;
	va_start(va, str);
	kprintf_va(str, va);
	va_end(va);
	kputc('\n');
}

static void setup(multiboot_info_t * multiboot) {
	//Textmode
	textmode_clear(); // Also initalizes textmode
	
	//GDT
	step("Initializing GDT...");
	gdt_init();
	step("Initializing IDT...");
	idt_init();

	//Memory	
	step("Initializing paging with %d MB...", (multiboot->mem_lower + multiboot->mem_upper)/1024);
	paging_init(multiboot);

	//Debuging
	step("Initializing Backtrace...");
	elf_init(&(multiboot->u.elf_sec));

	//Exceptions
	step("Initializing enabling Exceptions...");
	__asm__ volatile("sti");

	//Multithreading
	step("Initializing Multithreading...");
	task_init();

	//Hardware
	step("Initializing PIT with %d HZ...", 100);
	pit_init(100/*HZ*/);

	//Register keyboard
	step("Initializing Keyboard driver...");
	kb_init();

	step("Initializing Initrd...");
	if (multiboot->mods_count == 0)
		panic("No initrd defined in grub.cfg!");
	
	uint32_t initrd_location = *((uint32_t *)multiboot->mods_addr);
  // uint32_t initrd_end = *(uint32_t *)(multiboot->mods_addr+4);
	fs_root = initrd_init(initrd_location);
}
