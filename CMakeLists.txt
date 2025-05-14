cmake_minimum_required(VERSION 3.13)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# initalize pico_sdk from installed location
# (note this can come from environment, CMake cache etc)
set(PICO_SDK_PATH $ENV{PICO_SDK_PATH})

#include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)
#include($ENV{PICO_SDK_PATH}/tools/CMakeLists.txt)

# Pull in Raspberry Pi Pico SDK (must be before project)
include(pico_sdk_import.cmake)

project(usb-to-serial-mouse C CXX ASM)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

# Add executable. Default name is the project name, version 0.1
add_executable(usb-to-serial-mouse main.c)

target_sources(usb-to-serial-mouse PRIVATE
			main.c
			usb_hid.c)

pico_set_program_name(usb-to-serial-mouse "usb-to-serial-mouse")
pico_set_program_version(usb-to-serial-mouse "0.1")

#pico_enable_stdio_uart(usb-to-serial-mouse 1)

# Add the standard library to the build
target_link_libraries(usb-to-serial-mouse pico_stdlib)
target_include_directories (usb-to-serial-mouse PUBLIC .)

# Add any user requested libraries
target_link_libraries(usb-to-serial-mouse
        pico_stdlib			
        hardware_timer
        hardware_uart
	tinyusb_host			
	tinyusb_board
        )

pico_add_extra_outputs(usb-to-serial-mouse)



