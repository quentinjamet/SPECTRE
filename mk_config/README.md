These are the scripts used to make a new, downscaled configuration from 
our previous 1/12, North Atlantic [CHAOCEAN](https://github.com/quentinjamet/chaocean) runs 

## Descrition of the scripts

- launch_python.slurm  

- mk_bathy.py  

- mk_ics.py   

- mk_atm.py

- mk_grid.py  

- mk_obcs.py


## The steps to make a new configuration

- First, make the grid with desired dx, dy, and dz grid parameters. The script ```mk_grid.py``` also provides ways to generate constant initial conditions, atmospheric forcing and opend boundary conditions in order to generate the model mesh. 

- Update the ```./code.SIZE.h``` and compile the code.

- update the ```./input/data.obcs``` file as well.

- 

- The bash script ```./SPECTRE/MITgcm/mk_grid/run_mk_grid.sh``` is made to run for 3 time steps. It uses the ```mklink_mk_grid``` script to make appropiate links for this short run.

- 

