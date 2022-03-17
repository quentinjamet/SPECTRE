To install, go to your preferred directoy (nothing heaving will be placed in there, this can be your /home/)

```$ confDir=${/your/pref/dir/}

```$ cd ${confDir}```

```$ git clone https://github.com/quentinjamet/SPECTRE ```

Go to the repo, then config directory:
```$ cd ./SPECTRE/MITgcm/```

Create the compiling and executable directory
```$ mkdir build exe```

Compile the code:
```$ ./Compile```

Go to run directory:
```$ cd ./memb000/```

Update the following variables in pc.vars:

```confDir=${conDir}/SPECTRE/MITgcm/```

```runDir=/glade/scratch/your_login/tmp_running/chao50```

```scrDir=${confDir}/SPECTRE/MITgcm/bin```

Create the run directory:

```mkdir -p /glade/scratch/your_login/tmp_running/chao50```

Update the informations on the slurm batch job ```run.sh```:

```#PBS -l walltime=00:59:00  -->> required run time```

```#PBS -M quentin.jamet@univ-grenoble-alpes.fr```

Run the code:
```$ qsub run.sh```


## Some usefull commands

- submit a job

```qsub your_job.sh```

- checking your job

```qstat -u your_login```

- Start an interaction session

```qsub -I -l select=1:ncpus=1:mpiprocs=1:mem=109GB -l walltime=05:00:00 -q regular -A UFSU0023```
