import numpy as np
import MITgcmutils as mit
#import xmitgcm as xmit
#import matplotlib.pyplot as plt
from scipy.interpolate import griddata
import os
from multiprocessing import Pool

#plt.ion()

#-- directories --
dir_grd12 = '/glade/p/univ/ufsu0011/runs/gridMIT_update1/'
dir_grd50 = '/glade/p/univ/ufsu0011/runs/chao50/gridMIT/'
dir_in  = '/glade/p/univ/ufsu0011/data_in/atmo_cond_12'
dir_out = '/glade/p/univ/ufsu0011/data_in/atmo_cond_50'

iper = 1963
tmpdir = str('%s/%04i' % (dir_out, iper))
if not os.path.isdir(tmpdir):
  os.makedirs( tmpdir )

#-- some parameters --
#[nr50, ny50, nx50] = [75, 1450, 1850]
[nr12, ny12, nx12] = [46, 900, 1000]
nt  = 1460         # +2 time records for begin/end interp

varN = ['t2', 'q2', 'u10', 'v10', 'radsw', 'radlw', 'precip']
nvar = len(varN)

# number of processors to use
# (should agree with those requested when lauching the interactive session)
# i.e. if nprocs = 36 (one full node)
# qsub -I -l select=1:ncpus=36:mpiprocs=36
#nproc=1462
nproc=36
#------------------------------------------------------------------
#       Make Atmospheric forcing files from our previous 1/12 runs
# -->>  need to update with 6-hourly forcing files from original DFS
#------------------------------------------------------------------
#-- grid params --
#- 1/12 -
xC12 = mit.rdmds(dir_grd12 + 'XC')
yC12 = mit.rdmds(dir_grd12 + 'YC')
xy12 = np.zeros([(ny12)*(nx12), 2])
xy12[:, 0] = xC12.reshape([ny12*nx12])
xy12[:, 1] = yC12.reshape([ny12*nx12])
#- 1/50 -
xC50 = mit.rdmds(dir_grd50 + 'XC')
yC50 = mit.rdmds(dir_grd50 + 'YC')
[ny50, nx50] = xC50.shape

#-- define horizontal interpolation --
def hz_interp(iii):
  print("Interpolating %s, time: %04i" % (varN[ivar], iii) ) 
  tmp_interp = griddata(xy12, var12[iii, :, :].reshape([ny12*nx12]), (xC50, yC50), method=mmeth)
  return tmp_interp

for ivar in range(6, nvar):
  #ivar = 6
  #-- input file --
  if varN[ivar] == 'precip':
    f = open( str("%s/precip_climExtd.box" % (dir_in) ), 'r')  
    var12 = np.fromfile(f, '>f4').reshape([nt+2, ny12, nx12])
    f.close()
  else:
    f = open( str("%s/%04i/%s_%04i.box" % (dir_in, iper, varN[ivar], iper) ), 'r')  
    var12 = np.fromfile(f, '>f4').reshape([nt+2, ny12, nx12])
    f.close()
  #- hz interp (with parallelization) -
  if varN[ivar] == 'u10' or varN[ivar] == 'v10':
    mmeth='cubic'
  else:
    mmeth='linear'
  #
  if __name__ == '__main__':
    p = Pool(nproc)
    tmp_var50 = p.map(hz_interp, np.arange(nt+2))
  #- reshape -
  var50 = np.zeros([nt+2, ny50, nx50])
  for iii in range(nt+2):
    var50[iii, :, :] = tmp_var50[iii]
  #- save -
  if varN[ivar] == 'precip':
    f = open( str("%s/precip_climExtd.bin" % (dir_out) ), 'ab' )
    var50.reshape([(nt+2)*ny50*nx50]).astype('>f4').tofile(f)
    f.close()
  else:
    f = open( str("%s/%04i/%s_%04i.bin" % (dir_out, iper, varN[ivar], iper) ), 'ab' )
    var50.reshape([(nt+2)*ny50*nx50]).astype('>f4').tofile(f)
    f.close()
  #
  del var12, var50
  

exit()



#-- interpolate --
f = open( str("%s/%04i/%s_%04i.bin" % (dir_out, iper, varN[ivar], iper) ), 'ab' )
for iit in range(0, nt+2):
    print("Interpolate %s, time: %04i/%04i" % (varN[ivar], iit, nt+2))
    var50 =  griddata(xy12, var12[iit, :, :].reshape([ny12*nx12]), (xC50, yC50), method='linear')
    #- save -
    var50.reshape([ny50*nx50]).astype('>f4').tofile(f)
#
f.close()


