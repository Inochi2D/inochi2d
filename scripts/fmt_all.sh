#!/bin/bash

# dfmt is bound to generate an error on registry.d
# as such, we ignore all the output.
dub run dfmt@~master -- -c . --i source/inochi2d/* &> /dev/null

# We use clang-format for C and typescript.
clang-format -i include/inochi2d.h web/inochi2d-ts/src/* web/inochi2d-pixijs/src/*