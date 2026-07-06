all: build-inochi2d build

MODEL?=../ada-static.inx

build-inochi2d:
	dub build --root=../../ --config=dynamic --build=release --dest $PWD/in_glrender
	- rm -f docs.json
	- rm -rf __dummy_docs/

build: build-inochi2d
	$(CC) -std=c23 main.c -Iout/include/ -Lout/ -linochi2d -lGLEW -lGL -lSDL3 -lm -o out/in_glrender

run: build
	LD_LIBRARY_PATH="out/:$LD_LIBRARY_PATH" ./out/in_glrender $(MODEL)

clean:
	- rm -rf out/