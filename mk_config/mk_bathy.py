import numpy as np
import MITgcmutils as mit
#import xmitgcm as xmit
import matplotlib.pyplot as plt
import xarray as xr
from scipy.interpolate import griddata


plt.ion()

#-- directories --
dir_grd = '/glade/p/univ/ufsu0011/initial_data/grid/'
dir_grd50 = '/glade/p/univ/ufsu0011/runs/chao50/gridMIT/'
dir_out = '/glade/p/univ/ufsu0011/data_in/grid_50/'
dir_fig = '/glade/u/home/qjamet/Figures/diag/'

xC50 = mit.rdmds(dir_grd50 + 'XC')
yC50 = mit.rdmds(dir_grd50 + 'YC')
[ny50, nx50] = xC50.shape
nr50 = 75

#-----------------------------------------
#       Make bathymetry
#----------------------------------------

#-- from GEBCO-2019 --
bathyGEBCO = xr.open_dataset(dir_grd + 'GEBCO_09_Mar_2022_2389ec3a50d8/gebco_2021_n58.798828125_s5.537109375_w-99.228515625_e-19.248046875.nc')
#- 

iiw = np.where((360+bathyGEBCO.lon.data) < xC50[0, 0]  )[0][-1] - 20
iie = np.where((360+bathyGEBCO.lon.data) < xC50[0, -1] )[0][-1] + 20
jjs = np.where(bathyGEBCO.lat.data < yC50[0, 0]  )[0][-1] - 20
jjn = np.where(bathyGEBCO.lat.data < yC50[-1, 0] )[0][-1] + 20
[nyGEB, nxGEB] = [jjn-jjs, iie-iiw]


#- interpolate -
xyGEB = np.zeros([(nyGEB)*(nxGEB), 2])
xyGEB[:, 0] = 360 + np.tile(bathyGEBCO.lon.data[np.newaxis, iiw:iie], (nyGEB, 1)).reshape([nyGEB*nxGEB])
xyGEB[:, 1] = np.tile(bathyGEBCO.lat.data[jjs:jjn, np.newaxis], (1, nxGEB)).reshape([nyGEB*nxGEB])
bathy50 = griddata(xyGEB, bathyGEBCO.elevation.data[jjs:jjn, iiw:iie].reshape([nyGEB*nxGEB]), (xC50, yC50), method='linear')
# MITgcm topo file need to be negative for z-coord
bathy50[np.where(bathy50>0.0)] = 0.0

#-- save --
f = open(dir_out + 'topo50_1st_guess_GEBCO.bin', 'wb')
bathy50.reshape([ny50*nx50]).astype('>f4').tofile(f)
f.close()


#----------------------------------------------------
# Do some adjustments to fill up lacsand other stuffs
#----------------------------------------------------
f = open(dir_out + 'topo50_1st_guess_GEBCO.bin', 'r')
bathy50 = np.fromfile(f, '>f4').reshape([ny50, nx50])
f.close()

#-- fill in wet points (from bathy file) with zero T --
#-- (get then with checkIniTemp/checkIniSalt at run time, default =.TRUE. ) --
f = open('/glade/p/univ/ufsu0011/data_in/ini_cond_50/ic000/t_ini50_ic000.bin', 'r')
tini = np.fromfile(f, '>f4').reshape([nr50, ny50, nx50])
f.close()
#- fill in T=0 wet points (should remove lacks and stuff like that )-
bathy50[np.where(tini[0, :, :]==0.0)] = 0.0

#-- fill in some points by hand --
bathy50[1100:, 510:680] = 0.0
bathy50[:25, :25] = 0.0

#-- save --
f = open(dir_out + 'topo50_update1.bin', 'wb')
bathy50.reshape([ny50*nx50]).astype('>f4').tofile(f)
f.close()



#-- plot --
mskNaN = bathy50 * 1.0
mskNaN[np.where(mskNaN < 0)] = 1.0
mskNaN[np.where(mskNaN == 0.0)] = np.nan

fig1 = plt.figure()
fig1.clf()
ax1 = fig1.add_subplot(1,1,1,)
cs1 = ax1.contourf(bathy50*mskNaN, 20, cmap='viridis_r')
cbax1 = fig1.add_axes([0.88, 0.2, 0.02, 0.6])
cb1 = fig1.colorbar(cs1, ax=ax1, orientation='vertical', cax=cbax1)
cb1.set_label(r'Bathymetry [m]', fontsize='large')
figN = 'bathy_chao50_GEBCO_update1'
fig1.savefig(dir_fig + figN + '.png', dpi=100, bbox_inches='tight')


