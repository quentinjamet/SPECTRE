# SPECTRE


The objective of this proposal is to contribute to eddy parameterization by means of novel examinations of ensembles of ocean simulations.

## Configuration

![alt tag](files/bathy_chao50_GEBCO_update1.png)

## Initial conditions, open boundaries and atmospheric forcing
Scripts used to build the inputs (forcing and initial conditions), along with their description, can be found in ```./mk_config/```.

- Initial conditions: The 48 members are initialized with the same initial conditions as those used to produce [https://github.com/quentinjamet/chaocean](CHAOCEAN), 1/12 North Atlantic ensemble simulations.

- Open boundary conditions: At the boundary of the domain, the ocean is forced by ocean state (T,S,U,V) inherited from [https://github.com/quentinjamet/chaocean](CHAOCEAN), 1/12 North Atlantic ensemble simulations.

- Atmospheric forcing: At the surface, the ocean model is coupled to the atmospheric boundary layer model CheapAML (Deremble et al, 2013). Atmospheric surface temperature and relative humidity respond to ocean surface structures by exchanges computed according to the COARE3 flux formula, but are strongly restored toward prescribed values over land. Other variables (downward longwave and solar shortwave radiation, precipitations) are prescribed everywhere. Atmospheric reanalysis products used in CheapAML originate from the Drakkar forcing set (DFS4.4, Brodeau et al, 2010; Dussin et al, 2016). Pricipitations are from DFS5.2 due to better time resolution. Atmospheric forcing are consistent with the previous, 1/12 North Altantic ensemble simulation [https://github.com/quentinjamet/chaocean](CHAOCEAN).


## Configuration files for MITgcm


## Simulations
Model ouptuts will be made available on request.

