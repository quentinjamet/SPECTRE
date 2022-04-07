These are the scripts used to make a new, downscaled configuration from 
our previous 1/12, North Atlantic [CHAOCEAN](https://github.com/quentinjamet/chaocean) runs. 

## Descrition of the scripts

The following scripts are used to generate new, downscaled model grid, along with associated bathymetry, initial conditions and (boundary and atmospheric) forcing files. Some scripts (```mk_ics.py```, ```mk_obcs.py```, ```mk_atm.py```) have been parallelized with ```Pool``` from ```multiprocessing``` python package (to be installed if needed). 

```MITgcmutils``` is used to read in MITgcm model outputs. You may need to make the following changes in the ```mds.py``` to solve a potential issue (which I did not understood ...):

line 126: ```val = [ parse1(s) for s in re.split(r'[, ] *',line) ]```

To interpolate 1/12 fields onto the new, 1/50 grid, we define their repsective grid in [m] with co-localized origin based on their lon/lat coordinates. Analytically, this reads: 

X<sub>50</sub>(i,j) = r<sub>earth</sub> (&theta;<sub>50</sub>(i, j)-&theta;<sub>50</sub>(i=0, j=0)) cos(&phi;<sub>50</sub>(i, j))

Y<sub>50</sub>(i,j) = r<sub>earth</sub> (&phi;<sub>50</sub>(i, j)-&phi;<sub>50</sub>(i=0, j=0))

X<sub>12</sub>(i,j) = r<sub>earth</sub> (&theta;<sub>12</sub>(i, j)-&theta;<sub>50</sub>(i=0, j=0)) cos(&phi;<sub>12</sub>(i, j))

Y<sub>12</sub>(i,j) = r<sub>earth</sub> (&phi;<sub>12</sub>(i, j)-&phi;<sub>50</sub>(i=0, j=0))

with (X, Y) the grid in [m] and (&theta;, &phi;) the grid in lon/lat.

- ```mk_grid.py```: Generate the 1-D ```del(X/Y/R)File``` specified in ```data``` file PARAM04, i.e. the zonal/meridional/vertical grid spacing (in lon/lat/meters) between cell faces. This script also generates flat bottom bathymetry and constant initial conditions and forcing files in order to first generate the esh of the new configuration. These are stored in appropriate ```./mk_grid/``` directories and are used by the script ```run_mk_grid.sh``` (see below).

- ```mk_bathy.py```: Interpolate GEBCO (or other reference bathy file) onto the new configuration mesh. It first produces a *first guess* bathymetry which you can then adjust (by hand most of the time) to remove land points associated with lacks and other annoying stuff (I have removed several wet points near Florida tip for instance). 

- ```mk_ics.py```: Interpolate 1/12 initial conditions onto the new, 1/50 downscaled model grid. The interpolation is first done in the horizontal, then in the vertical (the inverse produces larger errors near bathymetry). Following Joseph Schoonover's downscaling approach, land points on the parent, 1/12 model grid are reprated as the last wet grid point to the east for tracers in order to avoid interpolating with 0.0 near the topography. Similarly in the vertical the last wet points are repeated downward. Initial conditions are directly read from the pickup.XXXXXXXXXX.data files with appropriate variable (U, V, T, S, Eta) ordering. 

- ```mk_obcs.py```: Interpolate 1/12, 5-day averaged model output onto the open boundaries of the downscaled configuration. This is made for each member and each year. Note that two additional time records are needed in these forcing files for proper time interpolation at the begin and at the end of each year. The two additional time records are placed at the end, where the last (second last) one corresponds to the last (first) time step of the preceding (following) year. [!!! Coded but not used for now (03/30/2022)!!!].

- ```mk_atm.py```: Interpolate the forcing files used for our previous 1/12 ensemble simulations onto the new, downscaled 1/50 grid. Nothing particular to consider here since no bathymetry issues and the two additional time records are already included in the orginial foring files.



## Steps to make a new configuration

- First, make the grid with desired ```dx```, ```dy```, and ```dz``` grid parameters. The script ```mk_grid.py``` will do that for you, along with generating flat bottom bathymetry, constant initial conditions, atmospheric forcing and opend boundary conditions in order to generate the model mesh at first. Link this flat bottom bathymetry file (in the ```/glade/p/univ/ufsu0011/data_in/grid_50/``` directory in our case) to ```topo50.bin```, the name used in ```data``` as topo file:

```$ ln -s topo50_flat_bottom.bin topo50.bin```

- Go to ```${your_pref_dir}/SPECTRE/MITgcm/```, update ```./code/SIZE.h``` with the appropriate grid points (and tilling!), then compile the with ```Compile.sh```. This procude an executable which is copied in ```./exe/``` directory along with the associate Makefile. 

- Update run time parameters ```OB_I/J*``` in PARM01 of ```./input/data.obcs```. You may also want to change the ```(xg/yg)Origin``` in ```./memb00/data``` PARAM04 (note: these are eastern/southern grid cell face coordinates of the lower left grid point of the domain). If you changes the name of the executable in the previous step, you need to update it in ```./memb000/pc.vars``` and ```./memb000/run_mk_grid.sh```.

- Run for a few (3) time steps to produce the desired grid using ```./memb000/run_mk_grid.sh```. The CPU request 
```#PBS -l select=20:ncpus=36:mpiprocs=36:mem=109GB```
should be adjusted to fit the ```nPx*nPy``` in ```./codr/SIZE.h```.

- Make the bathymetry with ```mk_bathy.py```. Depending on the domain, you may need to fill in some grid points by hand to avoid issues. (By experience, this may also arise after a decent number of iterations in shallow water area due to cheapaml). Account for this new bathymetry by updating the link ```topo50.bin``` made in the previous step.

- Re-run ```./memb000/run_mk_grid.sh``` with this new bathymetry (don't forget to update it with ```$ ln -s topo50_update1.bin topo50.bin```).

- Construct the appropriate initial conditions, boundary and atmospheric forcing files with ```mk_ics.py```, ```mk_obcs.py``` and ```mk_atm.py```. These scripts use parallelized procedures for horizontal and vertical interpolations (```nproc=36``` in the present exemple). To leverage this, they should be launched with appropriate ressources which can be obtained with an interactive session:

```$ qsub -I -l select=1:ncpus=36:mpiprocs=36:mem=109GB -l walltime=01:00:00 -q regular -A UFSU0023```

- And finally, go back to ```${your_pref_dir}/SPECTRE/MITgcm/memb000``` and launch a pre-production run using ```run.sh```. This script call few others (in ```./MITgcm/bin/```) to make appropriate links and move model outputs at the end of a run before re-launching itself.
