#!/bin/bash
#dirModel='/glade/p/work/qjamet/MITgcm'
#-- change of file system summer 2018 --
dirModel='../MITgcm_c67c'	#Checkpoint c67c
optfile='cheyenne_amd64_openmpi'

#-- switch mpt to impi --
#module unload mpt/2.15f
#module load   impi/2017.1.132 
#-- 0612/2019 --
# recompile to update mpt libraries

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
