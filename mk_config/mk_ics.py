import numpy as np
import MITgcmutils as mit
import matplotlib.pyplot as plt
import xarray as xr
import os
from scipy.interpolate import griddata
from scipy.interpolate import interp1d
from multiprocessing import Pool

#plt.ion()

#-- directories --
dir_grd12 = '/glade/p/univ/ufsu0011/runs/gridMIT_update1/'
dir_grd50 = '/glade/p/univ/ufsu0011/runs/chao50/gridMIT/'
#dir_ic12  = '/glade/p/univ/ufsu0011/data_in/ini_cond_12/ensemble_ic'
dir_ic12  = '/glade/p/univ/ufsu0011/runs/orar/memb00/run2002'
dir_ic50  = '/glade/p/univ/ufsu0011/data_in/ini_cond_50'

dir_fig = '/tank/chaocean/scripts_py/chao50/'
#-- some parameters --
#iiter = 946080
iiter = 7095600

varN = ['u', 'v', 't', 's']
nvar = len(varN)
# varNb should match pickup fil ordering
# 'Uvel    ' 'Vvel    ' 'Theta   ' 'Salt    ' 'GuNm1   ' 'GvNm1   ' 'EtaN    ' 'dEtaHdt ' 'EtaH    '
varNb = [0, 1, 2, 3]
# with an interative session: qsub -I -l select=1:ncpus=36:mpiprocs=36
nproc = 36      #number of processors used for parallelization
mmeth = 'cubic'

#------------------------------------------------------------------
#	Make Initial conditions from our previous 1/12 runs
#------------------------------------------------------------------

#-- grid params (hz grid are variable dependent) --
# hz grid: defined in km with adjusted parent and child grid origin
# it is variable depend, see in the ivar loop further down 
rSphere = 6370000.0

#- vertical grid -
# 1/12
rC12 = mit.rdmds(dir_grd12 + 'RC')
rF12 = mit.rdmds(dir_grd12 + 'RF')
nr12 = len(rC12[:, 0,0])
zzz12 = np.zeros([nr12+2])
zzz12[1:-1] = rC12[:, 0, 0]
zzz12[-1] = rF12[-1, 0, 0]
hC12 = mit.rdmds(dir_grd12 + 'hFacC')
# 1/50
rC50 = mit.rdmds(dir_grd50 + 'RC')
nr50 = len(rC50[:, 0,0])
mskC = mit.rdmds(dir_grd50 + 'hFacC')
mskC[np.where(mskC > 0.0) ] = 1.0
mskC[np.where(mskC == 0.0) ] = np.nan


#-- pre-loading -- 
iic = 000
tmpdir = str('%s/ic%03i' % (dir_ic50, iic))
if not os.path.isdir(tmpdir):
  os.mkdir( tmpdir )
#- from pickups -
#tmpocn = mit.rdmds( str('%s/ic%02i/pickup.%010i' % (dir_ic12, iic, iiter)) )
tmpocn = mit.rdmds( str('%s/ocn/pickup.%010i' % (dir_ic12, iiter)) )

#-- define horizontal interpolation --
def hz_interp(kkkk):
  print("Interpolating %s, level k=%03i" % (varN[ivar], kkkk) )
  tmp_interp = griddata(xy12, var12[kkkk, :, :].reshape([ny12*nx12]), (xx50, yy50), method=mmeth)
  return tmp_interp

#-- define vertical interpolation --
def zinterp(ji):
  print("Vertically interpolating %s, %02.02f perc completed" % (varN[ivar], ji/(nx50*ny50)*100.0) )
  tmpvar50 = var50_z46[:, ji]
  # FOR TRACER ONLY
  # find last wet point and repeat it downward for constant interpolation -
  if varN[ivar] == 't' or varN[ivar] == 's':
    tmpk = np.where( tmpvar50 == 0.0 )[0]
    if tmpk.size > 0:
      if (tmpk[0] > 0 and tmpk[0] < (nr12+1) ):
        tmpvar50[tmpk[0]:] = tmpvar50[tmpk[0]-1]
  #
  f = interp1d(zzz12, tmpvar50)
  tmp_interpz = f(rC50[:, 0, 0])
  return tmp_interpz
   

#-- interpolate --
for ivar in range(nvar):
  #- make appropriate (t-,u-,v-points) horizontal grid -
  if varN[ivar] == 'u':
    # 1/50
    x50deg = mit.rdmds(dir_grd50 + 'XG')
    y50deg = mit.rdmds(dir_grd50 + 'YC')
    # 1/12
    x12deg = mit.rdmds(dir_grd12 + 'XG')
    y12deg = mit.rdmds(dir_grd12 + 'YC')
  elif varN[ivar] == 'v':
    # 1/50
    x50deg = mit.rdmds(dir_grd50 + 'XC')
    y50deg = mit.rdmds(dir_grd50 + 'YG')
    # 1/12
    x12deg = mit.rdmds(dir_grd12 + 'XC')
    y12deg = mit.rdmds(dir_grd12 + 'YG')
  else:
    # 1/50
    x50deg = mit.rdmds(dir_grd50 + 'XC')
    y50deg = mit.rdmds(dir_grd50 + 'YC')
    # 1/12
    x12deg = mit.rdmds(dir_grd12 + 'XC')
    y12deg = mit.rdmds(dir_grd12 + 'YC')
  [ny50, nx50] = x50deg.shape
  [ny12, nx12] = x12deg.shape
  # make hz grid in km with co-localized origin
  xx50 = np.radians(x50deg - x50deg[0,0]) * rSphere * np.cos(np.radians(y50deg))
  yy50 = np.radians(y50deg - y50deg[0,0]) * rSphere
  xx12 = np.radians(x12deg - x50deg[0,0]) * rSphere * np.cos(np.radians(y12deg))
  yy12 = np.radians(y12deg - y50deg[0,0]) * rSphere
  xy12 = np.zeros([(ny12)*(nx12), 2])
  xy12[:, 0] = xx12.reshape([ny12*nx12])
  xy12[:, 1] = yy12.reshape([ny12*nx12])
  #- pick from pickupfile -
  var12 = tmpocn[varNb[ivar]*nr12:(varNb[ivar]+1)*nr12, :, :]
  #- make some adjustments near land points (FOR TRACER ONLY) -
  if varN[ivar] == 't' or varN[ivar] == 's':
    for kk in range(nr12):
      for jj in range(ny12):
        for ii in range(nx12-1, -1, -1):
          if var12[kk, jj, ii] == 0.0:
            var12[kk, jj, ii] = vlast
          else:
            vlast = var12[kk, jj, ii]
  #- hz interp (with parallelization) -
  if __name__ == '__main__':
    p = Pool(nproc)
    tmp_var50 = p.map(hz_interp, np.arange(nr12))
  #- reshape -
  var50_z46 = np.zeros([nr12+2, ny50, nx50])
  for kkk in range(nr12):
    var50_z46[kkk+1, :, :] = tmp_var50[kkk]
  var50_z46[0, :, :] = var50_z46[1, :, :]
  var50_z46[-1, :, :] = var50_z46[-2, :, :]
  #- vert interpolation (with parallelization) -
  var50_z46 = var50_z46.reshape([nr12+2, ny50*nx50])
  if __name__ == '__main__':
    p = Pool(nproc)
    tmp_var50_z75 = p.map(zinterp, np.arange(ny50*nx50))
  #- reshape -
  var50_z75 = np.zeros([nr50, ny50*nx50])
  for ji in range(ny50*nx50):
    var50_z75[:, ji] = tmp_var50_z75[ji]
  var50_z75 = var50_z75.reshape([nr50, ny50, nx50])
  #- save -
  f = open( str("%s/%s_ini50_ic%03i.bin" %(tmpdir, varN[ivar], iic) ), 'wb')
  var50_z75.astype('>f4').tofile(f)
  f.close()
  #- sanity check -
  if varN[ivar] == 't' or varN[ivar] == 's':
    [kk, jj, ii] = np.where(var50_z75*mskC == 0.0)
    if jj.any():
      print("WARNING: There is wet points with %s=0.0, MITgcm does not like that :( ..." % ( varN[ivar]) )
  #
  del var12, var50_z46, var50_z75


#-----------------------------------
# Surface fields (Eta, t2,q2)
#-----------------------------------
#-- eta --
print('-- interpolate eta --')
eta12 = tmpocn[nr12*6, :, :]
#- hz interp -
eta50 = griddata(xy12, eta12.reshape([ny12*nx12]), (xx50, yy50), method='linear')
#- save -
f = open( str("%s/eta_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
eta50.reshape([ny50*nx50]).astype('>f4').tofile(f)
f.close()

#-- cheapaml initial conditions --
tmpcheap = mit.rdmds( str('%s/cheapaml/pickup_cheapaml.%010i' % (dir_ic12, iiter)) )
#-- atmospheric t2 --
print('-- interpolate t2 (cheapaml) --')
t2_12 = tmpcheap[0, :, :]
#- hz interp -
t2_50 = griddata(xy12, t2_12.reshape([ny12*nx12]), (xx50, yy50), method='linear')
#- save -
f = open( str("%s/t2_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
t2_50.reshape([ny50*nx50]).astype('>f4').tofile(f)
f.close()
print('-- interpolate q2 (cheapaml) --')
#-- atmospheric q2 --
q2_12 = tmpcheap[2, :, :]
#- hz interp -
q2_50 = griddata(xy12, q2_12.reshape([ny12*nx12]), (xx50, yy50), method='linear')
#- save -
f = open( str("%s/q2_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
q2_50.reshape([ny50*nx50]).astype('>f4').tofile(f)
f.close()

exit()

#-----------------------------------------
# Restoring mask
#-----------------------------------------
print('-- Make RBCS masks --')
rmask = np.ones([nr50, ny50, nx50])
f = open( str("%s/tsuv_relax_mask.bin" %(dir_ic50) ), 'wb')
rmask.reshape([nr50*ny50*nx50]).astype('>f4').tofile(f)
f.close()




exit()


