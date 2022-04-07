import numpy as np
import xarray as xr

#-- directories --
dir_out = '/glade/p/univ/ufsu0011/data_in/grid_50/'
dir_grd = '/glade/p/univ/ufsu0011/initial_data/grid/'

#-- original mesh parameters --
[nr, ny, nx] = [75, 1000,2052]
delxy = 1/50

#-----------------------------------------
#	Make the horizontal mesh
#	as dxG and dyG (zonal and meridional grid spacing at t-point)
#	but in degree (spherical polar grid)
#-----------------------------------------

dxG = delxy * np.ones([nx])
dyG = delxy * np.ones([ny])
#-- save --
f = open(dir_out + 'dx50.bin', 'wb')
dxG.astype('>f4').tofile(f)
f.close()
f = open(dir_out + 'dy50.bin', 'wb')
dyG.astype('>f4').tofile(f)
f.close()

#-----------------------------------------
#	Make the vertical mesh
#	as drF (vertical grid spacing at t-point)
#-----------------------------------------

#-- take it from eORCA12.L75 grid --
mesh_eORCA12_L75 = xr.open_dataset(dir_grd + 'eORCA12.L75_mesh_mask.nc')
drF = mesh_eORCA12_L75.e3t_1d[0, :].data
rF  = np.zeros([nr+1, 1, 1])
rF[1:, 0, 0] = -np.cumsum(drF)
#-- save --
f = open(dir_out + 'dz50.bin', 'wb')
drF.astype('>f4').tofile(f)
f.close()


#----------------------------------------------------
# Generate idealized conditions to produce model grid
#----------------------------------------------------

#-- flat bottom --
H0 = -6000      #[m]
bathy = H0 * np.ones([ny, nx])
#- save -
f = open(dir_out + 'topo50_flat_bottom.bin', 'wb')
bathy.reshape([ny*nx]).astype('>f4').tofile(f)
f.close()

#-- initial conditions --
tmpdir = '/glade/p/univ/ufsu0011/data_in/ini_cond_50/mk_grid'
varN = ['t', 's', 'u', 'v', 'eta']
iniVal = [15.0, 35.0, 0.0, 0.0, 0.0]
nvar = len(varN)
for ivar in range(nvar):
  print('Make ICs for: %s' % varN[ivar])
  if varN[ivar] == 'eta':
    tmpvar = iniVal[ivar] * np.ones([ny, nx])
    f = open( str("%s/%s_ini50_cst.bin" %(tmpdir, varN[ivar]) ), 'wb')
    tmpvar.astype('>f4').tofile(f)
    f.close()
  else:
    tmpvar = iniVal[ivar] * np.ones([nr, ny, nx])
    f = open( str("%s/%s_ini50_cst.bin" %(tmpdir, varN[ivar]) ), 'wb')
    tmpvar.astype('>f4').tofile(f)
    f.close()

#-- atmpospheric forcing --
tmpdir = '/glade/p/univ/ufsu0011/data_in/atmo_cond_50/mk_grid'
nt = 1460
varN = ['u10', 'v10', 't2', 'q2', 'radsw', 'radlw', 'precip']
nvar = len(varN)
for ivar in range(nvar):
  print('Make atm forcing for: %s' % varN[ivar])
  tmpvar = np.zeros([(nt+2), ny, nx])
  f = open( str("%s/%s_cst.bin" %(tmpdir, varN[ivar]) ), 'wb')
  tmpvar.astype('>f4').tofile(f)
  f.close()


#-- boundary conditions --
tmpdir='/glade/p/univ/ufsu0011/data_in/bound_cond_50/mk_grid'
nt = 73
varN = ['t', 's', 'uE', 'vN']
iniVal = [15.0, 35.0, 0.0, 0.0]
nvar = len(varN)
bbdy = ['south', 'north', 'east', 'west']
nbdy = len(bbdy)
for ibdy in range(nbdy):
  if bbdy[ibdy] == 'south' or bbdy[ibdy] == 'north':
    nxy = nx
  else:
    nxy = ny
  for ivar in range(nvar):
    print("Make boundary conditions for %s at %s" %(varN[ivar], bbdy[ibdy]))
    tmpvar = iniVal[ivar] * np.ones([nt+2, nr, nxy])
    f = open( str("%s/%s_%s_cst.bin" %(tmpdir, varN[ivar], bbdy[ibdy]) ), 'wb')
    tmpvar.astype('>f4').tofile(f)
    f.close()


