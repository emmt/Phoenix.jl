#
# Makefile --
#
# Rules to build utilities and wrapper for the Activision Phoenix frame
# grabber library and Mikrotron MC408x camera.
#
#-------------------------------------------------------------------------------
#
# This file is part of the `Phoenix.jl` package which is licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2017, Éric Thiébaut.
#

srcdir = .

# Macros for compiling with Activevision Phoenix library:
PHX_DIR = /usr/local/activesilicon
PHX_LIBDIR = $(PHX_DIR)/lib64
PHX_INCDIR = $(PHX_DIR)/include
PHX_DEFS = -D_PHX_LINUX -I$(PHX_INCDIR)
PHX_DLL = $(PHX_LIBDIR)/libphxapi-x86_64.so
PHX_LIBS = -L$(PHX_LIBDIR) -lphxfb02-x86_64 -lphxapi-x86_64 -lphxbl-x86_64 -lphxil-x86_64 -lphxdl-x86_64 -lrt -ldl

PIC_FLAGS = -fPIC
CC = gcc
CPPFLAGS = -I.
CFLAGS = -O2 -Wall
LDFLAGS =

default: all

clean:
	rm -f *~ *.o gencode

all: $(srcdir)/../src/constants.jl

$(srcdir)/../src/constants.jl: gencode gencode.sh
	rm -f "$@"
	./gencode.sh "$@"
	chmod a-w "$@"

gencode: gencode.c Makefile
	$(CC) $(CPPFLAGS) $(PHX_DEFS) $(CFLAGS) \
	    -DPHX_DLL=\"$(PHX_DLL)\" $< -o $@
