set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

#set(cross_triple "x86_64-linux-gnu")
set(cross_triple "x86_64-redhat-linux")


set(CMAKE_C_COMPILER $ENV{CC})
set(CMAKE_CXX_COMPILER $ENV{CXX})
set(CMAKE_Fortran_COMPILER $ENV{FC})
set(CMAKE_ASM_COMPILER ${CMAKE_C_COMPILER})

set(CMAKE_CROSSCOMPILING_EMULATOR /usr/bin/${cross_triple}-noop)
