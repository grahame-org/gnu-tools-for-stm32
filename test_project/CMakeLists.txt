cmake_minimum_required(VERSION 3.15.3)

project(nucleo-u083rc)

enable_language(C ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# These source files are compiled in the same order as they are listed.
# This ordering was determined by reviewing the order that CubeIDE's
# build console output showed them being built.
#
# In principle the ordering of compiling the source files into object
# files should not matter as they could potentially be built in parallel.
set(STM32CUBEMX_GENERATED_FILES

        BSP/Drivers/BSP/STM32U0xx_Nucleo/stm32u0xx_nucleo.c

        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_cortex.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_dma.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_dma_ex.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_exti.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_flash.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_flash_ex.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_gpio.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_pwr.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_pwr_ex.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_rcc.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_rcc_ex.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_uart.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_uart_ex.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_usart.c
        BSP/Drivers/STM32U0xx_HAL_Driver/Src/stm32u0xx_hal_usart_ex.c

        BSP/Src/main.c
        BSP/Src/stm32u0xx_hal_msp.c
        BSP/Src/stm32u0xx_it.c
        BSP/Src/syscalls.c
        BSP/Src/sysmem.c
        BSP/Src/system_stm32u0xx.c
        
        BSP/startup_stm32u083xx.s)

set(EXECUTABLE ${PROJECT_NAME}.elf)

add_executable(${EXECUTABLE} ${STM32CUBEMX_GENERATED_FILES})

# These definitions are specified in the same order that CubeIDE
# uses them when compiling a source file into an object file.
target_compile_definitions(${EXECUTABLE} PRIVATE
        -DUSE_NUCLEO_64
        -DUSE_HAL_DRIVER
        -DSTM32U083xx
        )

# Includes paths are searched in the order they are specified.
# This can impact the resulting pre-processed source files and
# consequently the object files generated when the pre-processed
# source files are compiled.
target_include_directories(${EXECUTABLE} PRIVATE
        BSP/Drivers/BSP/STM32U0xx_Nucleo/
        BSP/Drivers/CMSIS/Device/ST/STM32U0xx/Include
        BSP/Drivers/CMSIS/Include
        BSP/Drivers/STM32U0xx_HAL_Driver/Inc
        BSP/Drivers/STM32U0xx_HAL_Driver/Inc/Legacy
        BSP/Inc
        )

# The compiler options have been ordered as per CubeIDE's invokation of the
# compiler.
target_compile_options(${EXECUTABLE} PRIVATE
        -mcpu=cortex-m0plus
        -c
        -O0
        -ffunction-sections
        -fdata-sections
        -Wall
        -Wextra
        -fstack-usage
        -MMD
        -MP        
        --specs=nano.specs
        -mfloat-abi=soft
        -mthumb
        $<$<CONFIG:Debug>:-Og>
        )

# When linking object files into a binary, the order of options is significant.
# The options need to be specified in the same order that CubeIDE passes them
# to the linker tool. Refer to the linker output in the CubeIDE console.
#
# target_link_options() places the list of objects to be linked after the
# list of options, this will generate a binary that does not match CubeIDE.
#
# target_link_libraries() places the list of objects to be linked before the
# list of options, which matches CubeIDE's invokation of the linker tool.
target_link_libraries(${EXECUTABLE} PRIVATE
        -mcpu=cortex-m0plus
        -T${CMAKE_SOURCE_DIR}/BSP/gcc_13_STM32U083RCTX_FLASH.ld
        --specs=nosys.specs
        -Wl,-Map=${PROJECT_NAME}.map
        -Wl,--cref
        -Wl,--gc-sections
        -static
        -specs=nano.specs
        -mfloat-abi=soft 
        -mthumb
        -Wl,--start-group
        -lc
        -lm
        -Wl,--end-group
)

# Print executable size
add_custom_command(TARGET ${EXECUTABLE}
        POST_BUILD
        COMMAND arm-none-eabi-size ${EXECUTABLE})

# Create hex file
add_custom_command(TARGET ${EXECUTABLE}
        POST_BUILD
        COMMAND arm-none-eabi-objcopy -O ihex ${EXECUTABLE} ${PROJECT_NAME}.hex
        COMMAND arm-none-eabi-objcopy -O binary ${EXECUTABLE} ${PROJECT_NAME}.bin)
