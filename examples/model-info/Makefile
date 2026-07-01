all: build-inochi2d build run

build-inochi2d:
	dub build --root=../../ --config=dynamic --build=release --dest $PWD/model-info
	- rm -f docs.json
	- rm -rf __dummy_docs/

build: build-inochi2d
	$(CC) main.c -Iout/include/ -Lout/ -linochi2d -o out/model-info

run: build
	LD_LIBRARY_PATH="out/:$LD_LIBRARY_PATH" ./out/model-info ../empty08.inx

clean:
	- rm -rf out/