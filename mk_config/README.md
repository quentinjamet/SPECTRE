These are the scripts used to make a new, downscaled configuration from 
our previous 1/12, North Atlantic [CHAOCEAN](https://github.com/quentinjamet/chaocean) runs 

## Descrition of the scripts

- mk_grid.py  

- mk_bathy.py  

- mk_ics.py   

- mk_obcs.py

- mk_atm.py



## The steps to make a new configuration

- First, make the grid with desired dx, dy, and dz grid parameters. The script ```mk_grid.py``` will do that for you, along with generating flat bottom bathymetry, constant initial conditions, atmospheric forcing and opend boundary conditions in order to generate the model mesh at first. 

- Go to ```${your_pref_dir}/SPECTRE/MITgcm/```, and run for a few (3) time steps to produce the desired grid using ```./memb000/run_mk_grid.sh```. Don't forget to update ```./code/SIZE.h``` before recompiling, and ```./input/data.obcs``` before running! 

- Make the bathymetry with ```mk_bathy.py```. Depending on the domain, you may need to fill in some grid points by hand to avoid issues. By experience, this may also arise after a decent number of iterations in shallow water area due to cheapaml.

- Re-run ```./memb000/run_mk_grid.sh``` with this new bathymetry.

- Construct the appropriate initial conditions, boundary and atmospheric forcing files with ```mk_ics.py```, ```mk_obcs.py``` and ```mk_atm.py```.
