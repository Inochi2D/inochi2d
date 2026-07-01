#include "inochi2d.h"
#include <stdio.h>
#include <stdint.h>

// This allows us to get messages from Inochi2D during loading.
void message_sink(const char *msg, const char *file, uint32_t line) {
	printf("%s(%d): %s\n", file, line, msg);
}

// Writes indentation.
void indent(uint32_t depth) {
	for(int i = 0; i < depth; i++)
		fputs("  ", stdout);
	fputs(" - ", stdout);
}

// Helper that prints a single node
void print_node(in_node_t *node, uint32_t depth) {
	indent(depth);
	printf("%s (%s)\n", in_node_get_name(node), in_node_get_type(node));

	int count;
	in_node_t **children = in_node_get_children(node, &count);
	for (int i = 0; i < count; i++) {
		print_node(children[i], depth+1);
	}
}

int main(int argc, char *argv[]) {

	// Handle no args.
	if (argc == 1) {
		printf("%s <model...>\n", argv[0]);
		return -1;
	}

	io_sink_t sink;
	sink.info = &message_sink;
	sink.warning = &message_sink;
	sink.error = &message_sink;

	for (int i = 1; i < argc; i++) {
		in_puppet_t *puppet = in_puppet_load(argv[i], &sink);
		printf(" - %d %s\n", i, argv[i]);
		if (puppet) {
			const char *name = in_puppet_get_name(puppet);
			const char *author = in_puppet_get_author(puppet);

			printf("   - name=%s\n", name ? name : "null");
			printf("   - author=%s\n", author ? author : "null");
			puts  ("   - nodes:");
			print_node(in_puppet_get_root_node(puppet), 3);
			in_puppet_free(puppet);
		}
	}
}