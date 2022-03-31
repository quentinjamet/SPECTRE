#!/bin/bash
##-- Job Name
#PBS -N mk_grid
##-- Project code
#PBS -A UFSU0023
#PBS -l walltime=00:09:00
#PBS -q premium
##-- Select 24 nodes with 36 CPUs each for a total of 864 MPI processes
##-- and require 128GB nodes (mem=109GB)
##PBS -l select=23:ncpus=36:mpiprocs=36:mem=109GB
#PBS -l select=41:ncpus=20:mpiprocs=20:mem=109GB
#PBS -m abe
#PBS -M quentin.jamet@univ-grenoble-alpes.fr

# export the qsub command into the bash script

#-----------------------------------------------------------------------------#
#     - Run time parameterers for input data, run dir and duration            #
#-----------------------------------------------------------------------------#
confDir=/glade/work/qjamet/Config/chao50
inDir=/glade/p/univ/ufsu0011/data_in
runDir=/glade/scratch/qjamet/tmp_running/chao50
outDir=/glade/p/univ/ufsu0011/runs/chao50
scrDir=/glade/work/qjamet/Config/chao50/bin
iit=0
nit=3
dt=5.0
pChkptFreq=0.
chkptFreq=0.
dumpFreq=50.
exe=mitgcmuv_test1

#-- make the run directory (all files will be linked there) --
if [ ! -d $runDir ]; then
 echo "run directory does not exist"$runDir > $monitor
 exit
else
 runDir2=$runDir/mk_grid
 if [ ! -d $runDir2 ]; then
  mkdir $runDir2
 else
  rm -rf $runDir2/*
 fi
fi

#-- set time parameters --
iit0=$( printf "010d" ${iit} )


#-----------------------------------------------------------------------------#
#     - Set data files for first iteration period                             #
#	and make grid, OBCS, cheapAML and pickup links
#-----------------------------------------------------------------------------#
. $scrDir/setdata $confDir/memb000 $iit $dt $nit $pChkptFreq \
                  $chkptFreq $dumpFreq

. $scrDir/mklink_mk_grid $runDir2 $confDir $inDir $exe \
                  $iit $iit0 $outDir 

#-----------------------------------------------#
#	 execute the model 			#
#-----------------------------------------------#
#-- go to running directory --
cd $runDir2
mpiexec_mpt dplace -s 1 ./$exe

#-- move grid --
. ${scrDir}/move_grid $runDir2 $outDir

