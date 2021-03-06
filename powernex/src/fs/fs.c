#include <powernex/fs/fs.h>

fs_node_t * fs_root = NULL;

uint32_t fs_read(fs_node_t * node, uint32_t offset, uint32_t size, uint8_t * buffer) {
	if (node->read)
		return node->read(node, offset, size, buffer);
	else
		return 0;
}

uint32_t fs_write(fs_node_t * node, uint32_t offset, uint32_t size, uint8_t * buffer) {
	if (node->write)
		return node->write(node, offset, size, buffer);
	else
		return 0;
}

void fs_open(fs_node_t * node) {
	if (node->open)
		node->open(node);
}

void fs_close(fs_node_t * node) {
	if (node->close)
		node->close(node);
}

fs_dirent_t * fs_readdir(fs_node_t * node, uint32_t index) {
	if (node->readdir && (node->flags & FS_DIRECTORY) == FS_DIRECTORY)
		return node->readdir(node, index);
	else
		return NULL;
}

fs_node_t * fs_finddir(fs_node_t * node, const char * name) {
	if (node->finddir && (node->flags & FS_DIRECTORY) == FS_DIRECTORY)
		return node->finddir(node, name);
	else
		return NULL;
}
