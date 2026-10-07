cmake_minimum_required(VERSION 3.22)
project(rtl_pty C)

add_library(rtl_pty SHARED rtl_pty.c)
target_link_libraries(rtl_pty log)
