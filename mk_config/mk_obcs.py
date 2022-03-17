import numpy as np
import MITgcmutils as mit
#import matplotlib.pyplot as plt
#import xarray as xr
import os
from scipy.interpolate import griddata
from scipy.interpolate import interp1d
from multiprocessing import Pool

#plt.ion()

#-- directories --
dir_grd12 = '/glade/p/univ/ufsu0011/runs/gridMIT_update1/'
dir_grd50 = '/glade/p/univ/ufsu0011/runs/chao50/gridMIT/'
dir_in  = '/glade/p/univ/ufsu0011/runs/orar'
dir_out = '/glade/p/univ/ufsu0011/data_in/bound_cond_50'

#-- some parameters --
nt = 73		#also need earlier and past year for interpolation

#-- grid params --
#- 1/12 -
xC12 = mit.rdmds(dir_grd12 + 'XC')
yC12 = mit.rdmds(dir_grd12 + 'YC')
xG12 = mit.rdmds(dir_grd12 + 'XC')
yG12 = mit.rdmds(dir_grd12 + 'YC')
rC12 = mit.rdmds(dir_grd12 + 'RC')
rF12 = mit.rdmds(dir_grd12 + 'RF')
hC12 = mit.rdmds(dir_grd12 + 'hFacC')
hS12 = mit.rdmds(dir_grd12 + 'hFacS')
hW12 = mit.rdmds(dir_grd12 + 'hFacW')
[nr12, ny12, nx12] = hC12.shape
zzz12 = np.zeros([nr12+2])
zzz12[1:-1] = rC12[:, 0, 0]
zzz12[-1] = rF12[-1, 0, 0]
#- 1/50 -
xC50 = mit.rdmds(dir_grd50 + 'XC')
yC50 = mit.rdmds(dir_grd50 + 'YC')
xG50 = mit.rdmds(dir_grd50 + 'XC')
yG50 = mit.rdmds(dir_grd50 + 'YC')
rC50 = mit.rdmds(dir_grd50 + 'RC')
hC50 = mit.rdmds(dir_grd50 + 'hFacC')
hS50 = mit.rdmds(dir_grd50 + 'hFacS')
hW50 = mit.rdmds(dir_grd50 + 'hFacW')
[nr50, ny50, nx50] = hC50.shape

varN = ['t', 's', 'uE', 'vN'] #sould correspond to diagnostics
nvar = len(varN)
bbdy = ['south', 'north', 'east', 'west']
nnbdy = len(bbdy)
# need to be consistent with ordering in bbdy
[sbdy, nbdy, wbdy, ebdy] = [yC50.min(), yC50.max(), xC50.min(), xC50.max()]


#------------------------------------------------------------------
#	Make Boundary conditions from our previous 1/12 runs
#------------------------------------------------------------------

iic = 000
iper = 1963
tmpdir = str('%s/%04i/ic%03i' % (dir_out, iper, iic))
if not os.path.isdir(tmpdir):
  os.makedirs( tmpdir )

#-- Loop over variables and boundaries --
for ivar in range(0, nvar):
  for ibdy in range(nnbdy):
    print("== Deal with %s at bdy %s ==" % (varN[ivar], bbdy[ibdy]) )
    #ivar = 0
    #ibdy = 0
    #
    #-- boundary parameteres --
    deltaxy = 10
    if bbdy[ibdy] == 'south':
      iiw = np.where(xC12[0,:]>wbdy)[0][0] - deltaxy
      iie = np.where(xC12[0,:]>ebdy)[0][0] + deltaxy
      jjs = np.where(yC12[:,0]>sbdy)[0][0] - deltaxy
      jjn = np.where(yC12[:,0]>sbdy)[0][0] + deltaxy
      if varN[ivar] == 't' or varN[ivar] == 's':
        hfac50 = hC50[:, 0, :]
        [yy50, xx50] = [ yC50[0, :], xC50[0, :] ]
      elif varN[ivar] == 'uE':
        hfac50 = hW50[:, 0, :]
        [yy50, xx50] = [ yC50[0, :], xG50[0, :] ]
      elif varN[ivar] == 'vN':
        hfac50 = hS50[:, 0, :]
        [yy50, xx50] = [ yG50[1, :], xC50[0, :] ]
      nxy50 = nx50
    elif bbdy[ibdy] == 'north':
      iiw = np.where(xC12[0,:]>wbdy)[0][0] - deltaxy
      iie = np.where(xC12[0,:]>ebdy)[0][0] + deltaxy
      jjs = np.where(yC12[:,0]>nbdy)[0][0] - deltaxy
      jjn = np.where(yC12[:,0]>nbdy)[0][0] + deltaxy
      if varN[ivar] == 't' or varN[ivar] == 's':
        hfac50 = hC50[:, -1, :]
        [yy50, xx50] = [ yC50[-1, :], xC50[-1, :] ]
      elif varN[ivar] == 'uE':
        hfac50 = hW50[:, -1, :]
        [yy50, xx50] = [ yC50[-1, :], xG50[-1, :] ]
      elif varN[ivar] == 'vN':
        hfac50 = hS50[:, -1, :]
        [yy50, xx50] = [ yG50[-1, :], xC50[-1, :] ]
      nxy50 = nx50
    elif bbdy[ibdy] == 'east':
      iiw = np.where(xC12[0,:]>ebdy)[0][0] - deltaxy
      iie = np.where(xC12[0,:]>ebdy)[0][0] + deltaxy
      jjs = np.where(yC12[:,0]>sbdy)[0][0] - deltaxy
      jjn = np.where(yC12[:,0]>nbdy)[0][0] + deltaxy
      if varN[ivar] == 't' or varN[ivar] == 's':
        hfac50 = hC50[:, :, -1]
        [yy50, xx50] = [ yC50[:, -1], xC50[:, -1] ]
      elif varN[ivar] == 'uE':
        hfac50 = hW50[:, :, -1]
        [yy50, xx50] = [ yC50[:, -1], xG50[:, -1] ]
      elif varN[ivar] == 'vN':
        hfac50 = hS50[:, :, -1]
        [yy50, xx50] = [ yG50[:, -1], xC50[:, -1] ]
      nxy50 = ny50
    elif bbdy[ibdy] == 'west':
      iiw = np.where(xC12[0,:]>wbdy)[0][0] - deltaxy
      iie = np.where(xC12[0,:]>wbdy)[0][0] + deltaxy
      jjs = np.where(yC12[:,0]>sbdy)[0][0] - deltaxy
      jjn = np.where(yC12[:,0]>nbdy)[0][0] + deltaxy
      if varN[ivar] == 't' or varN[ivar] == 's':
        hfac50 = hC50[:, :, 0]
        [yy50, xx50] = [ yC50[:, 0], xC50[:, 0] ]
      elif varN[ivar] == 'uE':
        hfac50 = hW50[:, :, 0]
        [yy50, xx50] = [ yC50[:, 0], xG50[:, 1] ]
      elif varN[ivar] == 'vN':
        hfac50 = hS50[:, :, 0]
        [yy50, xx50] = [ yG50[:, 0], xC50[:, 0] ]
      nxy50 = ny50
    #
    [ny2, nx2] = [jjn-jjs, iie-iiw]
    #
    #-- variables parameters --
    xy12 = np.zeros([(ny2)*(nx2), 2])
    if varN[ivar] == 't' or varN[ivar] == 's':
      flag_repz = True	#to repeat grid points downward for vert. interp
      hfac12 = hC12
      xy12[:, 0] = xC12[jjs:jjn,iiw:iie].reshape([ny2*nx2])
      xy12[:, 1] = yC12[jjs:jjn,iiw:iie].reshape([ny2*nx2])
    elif varN[ivar] == 'uE':
      flag_repz = False
      hfac12 = hW12
      xy12[:, 0] = xG12[jjs:jjn,iiw:iie].reshape([ny2*nx2])
      xy12[:, 1] = yC12[jjs:jjn,iiw:iie].reshape([ny2*nx2])
    elif varN[ivar] == 'vN':
      flag_repz = False
      hfac12 = hS12
      xy12[:, 0] = xC12[jjs:jjn,iiw:iie].reshape([ny2*nx2])
      xy12[:, 1] = yG12[jjs:jjn,iiw:iie].reshape([ny2*nx2])
    #
    #-- vertical interpolation --
    print('Vertical interpolation ...')
    var12 = np.zeros([nt, nr12+2, ny2, nx2])
    var12[:, 1:-1, :, :] =  mit.rdmds( str("%s/memb%02i/run%04i/ocn/diag_ocnTave" \
            % (dir_in, iic, iper) ), \
            itrs=np.nan, rec=ivar, region=[iiw, iie, jjs, jjn], usememmap=True ) \
    	* hfac12[np.newaxis, :, jjs:jjn, iiw:iie]
    var12[:, 0, :, :]  = var12[:, 1, :, :]
    var12[:, -1, :, :] = var12[:, -2, :, :]
    #
    var12_z75 = np.zeros([nt, nr50, ny2, nx2])
    for iit in range(nt):
      print("time: %03i" % iit)
      for jjj in range(ny2):
         for iii in range(nx2):
           # find last wet point and repeat it downward for constant interpolation 
           if flag_repz:
             tmpk = np.where(var12[0, :, jjj, iii] == 0.0 )[0]
             if tmpk.size > 0:
              if (tmpk[0] > 0 and tmpk[0] < (nr12+1) ):
               var12[iit, tmpk[0]:, jjj, iii] = var12[iit, tmpk[0]-1, jjj, iii]
           # vertical interpolation
           f = interp1d(zzz12, var12[iit, :, jjj, iii])
           var12_z75[iit, :, jjj, iii] = f(rC50[:, 0, 0])
    #
    #-- horizontal interpolation --
    print('Horizontal interpolation ...')
    var50 = np.zeros([nt+2, nr50, nxy50])
    for iit in range(nt):
      for kkk in range(nr50):
        print('(time, level): (%03i, %03i)' % (iit, kkk) )
        var50[iit+1, kkk, :] = griddata( xy12, var12_z75[iit, kkk, :, :].reshape([ny2*nx2]), (xx50, yy50), method='linear' ) * hfac50[kkk, :]
    var50[0, :, :]  = var50[1, :, :]
    var50[-1, :, :] = var50[-2, :, :]
    #
    #-- save --
    print('Save ...')
    f = open( str("%s/%s_%s_%04i_ic%03i.bin" % \
    	(tmpdir, varN[ivar], bbdy[ibdy]  ,iper, iic) ), 'wb')
    var50.reshape([(nt+2)*nr50*nxy50]).astype('>f4').tofile(f)
    f.close()
    #
    del var12, var12_z75, var50 
