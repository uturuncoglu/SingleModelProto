# GNU Makefile template for user ESMF application

################################################################################
################################################################################
## This Makefile must be able to find the "esmf.mk" Makefile fragment in the  ##
## 'include' line below. Following the ESMF User's Guide, a complete ESMF     ##
## installation should ensure that a single environment variable "ESMFMKFILE" ##
## is made available on the system. This variable should point to the         ##
## "esmf.mk" file.                                                            ##
##                                                                            ##
## This example Makefile uses the "ESMFMKFILE" environment variable.          ##
##                                                                            ##
## If you notice that this Makefile cannot find variable ESMFMKFILE then      ##
## please contact the person responsible for the ESMF installation on your    ##
## system.                                                                    ##
## As a work-around you can simply hardcode the path to "esmf.mk" in the      ##
## include line below. However, doing so will render this Makefile a lot less ##
## flexible and non-portable.                                                 ##
################################################################################

ifneq ($(origin ESMFMKFILE), environment)
$(error Environment variable ESMFMKFILE was not set.)
endif

include $(ESMFMKFILE)

################################################################################
################################################################################

CC     = icc 
F90    = ifort
PYTHON = python3
PYTHON_INCLUDE_DIR = /glade/u/apps/ch/opt/python/3.7.9/gnu/9.1.0/include/python3.7m
PYTHON_LIB_DIR = /glade/u/apps/ch/opt/python/3.7.9/gnu/9.1.0/lib

################################################################################
################################################################################

ifeq ($(F90),gfortran)
  F90FLAGS = -fPIC
endif

CFLAGS = -fPIC

################################################################################
################################################################################

UNAME = $(shell uname)

ifeq (${UNAME}, Darwin)
  LIBTOOL = libtool -static -o
else
  LIBTOOL = ar src
endif

################################################################################
################################################################################

CONDUIT_DIR=/glade/work/turuncu/NEW_IDEAS/progs/conduit-0.7.1/install
include $(CONDUIT_DIR)/share/conduit/conduit_config.mk
CONDUIT_DIR_PY=/glade/u/home/turuncu/.local/lib/python3.7/site-packages/conduit

################################################################################
################################################################################

.SUFFIXES: .f90 .F90 .c .C .cpp .CPP

%.o : %.f90
	$(ESMF_F90COMPILER) -c $(ESMF_F90COMPILEOPTS) $(ESMF_F90COMPILEPATHS) $(ESMF_F90COMPILEFREENOCPP) $(F90FLAGS) $<

%.o : %.F90
	$(ESMF_F90COMPILER) -c $(ESMF_F90COMPILEOPTS) $(ESMF_F90COMPILEPATHS) $(ESMF_F90COMPILEFREECPP) $(ESMF_F90COMPILECPPFLAGS) -DESMF_VERSION_MAJOR=$(ESMF_VERSION_MAJOR) $(CONDUIT_INCLUDE_FLAGS) $(F90FLAGS) $<

%.o : %.c
	$(ESMF_CXXCOMPILER) -c $(ESMF_CXXCOMPILEOPTS) $(ESMF_CXXCOMPILEPATHSLOCAL) $(ESMF_CXXCOMPILEPATHS) $(ESMF_CXXCOMPILECPPFLAGS) $(CFLAGS) $<

%.o : %.C
	$(ESMF_CXXCOMPILER) -c $(ESMF_CXXCOMPILEOPTS) $(ESMF_CXXCOMPILEPATHSLOCAL) $(ESMF_CXXCOMPILEPATHS) $(ESMF_CXXCOMPILECPPFLAGS) $(CFLAGS) $<

%.o : %.cpp
		$(ESMF_CXXCOMPILER) -c $(ESMF_CXXCOMPILEOPTS) $(ESMF_CXXCOMPILEPATHSLOCAL) $(ESMF_CXXCOMPILEPATHS) $(ESMF_CXXCOMPILECPPFLAGS) $(CFLAGS) -I $(PYTHON_INCLUDE_DIR) $(CONDUIT_INCLUDE_FLAGS) -I $(CONDUIT_DIR_PY) $(CONDUIT_INCLUDE_FLAGS_PY) $<

%.o : %.CPP
		$(ESMF_CXXCOMPILER) -c $(ESMF_CXXCOMPILEOPTS) $(ESMF_CXXCOMPILEPATHSLOCAL) $(ESMF_CXXCOMPILEPATHS) $(ESMF_CXXCOMPILECPPFLAGS) $(CFLAGS) $<

# -----------------------------------------------------------------------------
mainApp: mainApp.o driver.o model.o mod_con.o mod_interface.o interface.o python_interpreter.o
	$(ESMF_F90LINKER) $(ESMF_F90LINKOPTS) $(ESMF_F90LINKPATHS) $(ESMF_F90LINKRPATHS) -o $@ $^ $(ESMF_F90ESMFLINKLIBS) $(CONDUIT_LINK_RPATH) $(CONDUIT_LIB_FLAGS) $(CONDUIT_MPI_LIB_FLAGS) -L $(PYTHON_LIB_DIR) -lpython3.7m

pywrapper: libpywrapper.a pywrapper.so

libpywrapper.a: pywrapper.o
		${LIBTOOL} $@ $?

pywrapper.so: libpywrapper.a
		f90wrap -m pywrapper pywrapper.f90 -k kind_map -v
		f2py-f90wrap --fcompiler=$(ESMF_F90COMPILER) --build-dir . -c -m _pywrapper f90wrap*.f90 -L. -lpywrapper

# module dependencies:
mainApp.o: driver.o
driver.o: model.o
model.o: mod_con.o
mod_con.o: mod_interface.o
mod_interface.o: interface.o python_interpreter.o

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
.PHONY: dust clean distclean info edit
dust:
	rm -f PET*.ESMF_LogFile *.nc *.stdout

clean:
	rm -f mainApp *.o *.mod

distclean: dust clean

info:
	@echo ==================================================================
	@echo ESMFMKFILE=$(ESMFMKFILE)
	@echo ==================================================================
	@cat $(ESMFMKFILE)
	@echo ==================================================================

edit:
	nedit mainApp.F90 driver.F90 model.F90 &

run:
	mpiexec_mpt -np 4 ./mainApp
