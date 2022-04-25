#!/bin/bash
#-- change of file system summer 2018 --
dirModel='../MITgcm_c67c'	#Checkpoint c67c
optfile='cheyenne_amd64_openmpi'

#-- load appropriate moduls --
module purge
module load ncarenv/1.3
module load intel/19.1.1
module load ncarcompilers/0.5.0
module load mpt/2.25
module load netcdf/4.8.1
echo "----------------------------"
module list
echo "----------------------------"

# COMPILE
cd ./build/
rm -rf ./*
$dirModel/tools/genmake2 -rootdir=$dirModel -mods=../code -mpi -optfile $dirModel/tools/build_options/$optfile
make depend
#make -j 16
make 
cd ../

cp -p ./build/mitgcmuv ./exe/mitgcmuv_test1
cp -p ./build/Makefile ./exe/Makefile_test1
