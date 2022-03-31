The following steps will guide you to reproduce the current configuration on the NCAR-Cheyenne supercomputer.

To start, define a directory ```tmpDir``` and clone the project there (nothing heaving will be placed in here, this can be your /home/):

```$ tmpDir=/your/pref/dir/```

```$ cd ${tmpDir}```

```$ git clone https://github.com/quentinjamet/SPECTRE ```

Go to the config directory:

```$ cd ./SPECTRE/MITgcm/```

Make the compiling (```build```) and executable (```exe```) directory. The former is where the code will be compiled (next step), and the later where the executable (```mitgcmuv```) will be stored:

```$ mkdir build exe```

Compile the code. You may wnat to update the name of the executable/Makefile at the end of the ```.sh``` script:

```$ ./Compile.sh```

Go to run directory:

```$ cd ./memb000/```

Update the following variables in ```pc.vars``` (the ```${tmpDir}``` need to be replace by its actual value, i.e. ```/your/pref/dir/``` int this example):

```confDir=${tmpDir}/SPECTRE/MITgcm/```

```runDir=/glade/scratch/your_login/tmp_running/chao50```

```scrDir=${tmpDir}/SPECTRE/MITgcm/bin```

Create the run directory (on scratch dir):

```mkdir -p /glade/scratch/your_login/tmp_running/chao50```

Update the informations on the slurm batch job ```run.sh```:

```#PBS -l walltime=00:59:00  -->> required run time```

```#PBS -M your@adress.com```

Run the code:
```$ qsub run.sh```


## Some usefull commands

- submit a job

```qsub your_job.sh```

- checking your job

```qstat -u your_login```

- Start an interaction session

```qsub -I -l select=1:ncpus=1:mpiprocs=1:mem=109GB -l walltime=05:00:00 -q regular -A UFSU0023```

- The script ```$tmpDir/MITgcm/bin/mk_memb_XXX.sh``` takes care of generating additional ensemble members based on a reference (```memb000``` in the example)

## Steps to make a new domain

All the scripts, along with the procedure, are detailled in ```./SPECTRE/mk_config/```.
