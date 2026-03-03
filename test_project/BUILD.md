# Build instructions

From the `test_project` directory, run

`$cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=./arm-none-eabi-gcc.cmake .`

`$cmake --build . --verbose -- -j 4`
