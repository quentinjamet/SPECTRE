#!/bin/bash
#PBS -N pp
#PBS -A UFSU0011
#PBS -l walltime=11:59:00
#PBS -q economy
#PBS -l select=1:ncpus=1:mpiprocs=1:mem=109GB
#PBS -m abe
#PBS -M quentin.jamet@univ-grenoble-alpes.fr


ulimit -s unlimited

tmp=${1}


STARTTIME=$(date +%s)
echo "==================="
echo "      START        "
echo $( date )

#--
echo '-- load module'
module load ncarenv
module load python
echo '-- activat virtual environement'
ncar_pylib my_npl_clone

toto=$( conda list )
echo $toto 
#-- 
echo '-- launch python script: ' $tmp
python3 $tmp

ENDTIME=$(date +%s)
ELAPSETIME=$(( $ENDTIME - $STARTTIME ))
echo "Elapse Time: $ELAPSETIME secs "
echo "      END          "
echo "==================="



