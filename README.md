# SingleModelProto
ESMF SingleModelProto code that is modified to demonstrate two-way ESMF/NUOPC and Python interaction

**To install Conduit:** 
```
module purge
module load intel/19.0.5
module load mpt/2.22
module load netcdf/4.7.4
module load python/3.7.9
module load cmake/3.18.2
module load ncarcompilers/0.5.0
module load ncarenv/1.3
module use /glade/p/cesmdata/cseg/PROGS/modulefiles/esmfpkgs/intel/19.0.5
module load esmf-8.1.0b47-ncdfio-mpt-g

wget https://github.com/LLNL/blt/archive/v0.3.6.tar.gz
tar -zxvf v0.3.6.tar.gz
rm v0.3.6.tar.gz
export BLT_SOURCE_DIR=$PWD/blt-0.3.6

wget https://github.com/LLNL/conduit/archive/v0.7.1.tar.gz
tar -zxvf v0.7.1.tar.gz
rm v0.7.1.tar.gz
cd conduit-0.7.1/
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX:PATH=$PWD/../install \
      -DPYTHON_MODULE_INSTALL_PREFIX:PATH=$HOME/.local/lib/python3.7/site-packages \
      -DPYTHON_EXECUTABLE:FILEPATH=/glade/u/apps/ch/opt/python/3.7.9/gnu/9.1.0/bin/python3 \
      -DBLT_SOURCE_DIR=/glade/work/turuncu/NEW_IDEAS/progs/blt-0.3.6 \
      -DENABLE_PYTHON=ON -DENABLE_FORTRAN=ON -DENABLE_MPI=ON ../src/
make
make install
```

**To run proto application (uses same modules that Counduit installation uses):**
```
# To access compute node in an interactive way on Cheyenne
qsub -I -l select=1:ncpus=36:mpiprocs=36 -l walltime=04:00:00 -q regular -A [PROJECT]

# Build example
# Edit Makefile and point correct files for PYTHON_INCLUDE_DIR, PYTHON_LIB_DIR, CONDUIT_DIR and CONDUIT_DIR_PY
make
make install
make run
```
