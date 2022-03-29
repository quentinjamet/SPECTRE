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
dir_ic12  = '/glade/p/univ/ufsu0011/data_in/ini_cond_12/ensemble_ic'
dir_ic50  = '/glade/p/univ/ufsu0011/data_in/ini_cond_50'

dir_fig = '/tank/chaocean/scripts_py/chao50/'
#-- some parameters --
iiter = 946080

varN = ['u', 'v', 't', 's']
nvar = len(varN)
# varNb should match pickup fil ordering
# 'Uvel    ' 'Vvel    ' 'Theta   ' 'Salt    ' 'GuNm1   ' 'GvNm1   ' 'EtaN    ' 'dEtaHdt ' 'EtaH    '
varNb = [0, 1, 2, 3]

nproc = 36      #number of processors used for parallelization


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
tmpocn = mit.rdmds( str('%s/ic%02i/pickup.%010i' % (dir_ic12, iic, iiter)) )

#-- define horizontal interpolation --
def hz_interp(kkkk):
  print("Interpolating %s, level k=%03i" % (varN[ivar], kkkk) )
  tmp_interp = griddata(xy12, var12[kkkk, :, :].reshape([ny12*nx12]), (xx50, yy50), method='linear')
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
    #msk = hC12*1.0
    #msk[np.where(msk) != 0.0 ] = 1.0
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
eta12 = tmpocn[nr12*6, :, :] * hC12[0, :, :]
#- hz interp -
eta50 = griddata(xy12, eta12.reshape([ny12*nx12]), (xx50, yy50), method='linear')
#- save -
f = open( str("%s/eta_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
eta50.reshape([ny50*nx50]).astype('>f4').tofile(f)
f.close()

#-- cheapaml initial conditions --
tmpcheap = mit.rdmds( str('%s/ic%02i/pickup_cheapaml.%010i' % (dir_ic12, iic, iiter)) )
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



#-----------------------------------------
# Restoring maks
#-----------------------------------------
print('-- Make RBCS masks --')
rmask = np.ones([nr50, ny50, nx50])
f = open( str("%s/tsuv_relax_mask.bin" %(dir_ic50) ), 'wb')
rmask.reshape([nr50*ny50*nx50]).astype('>f4').tofile(f)
f.close()




exit()



#-- temperature --
ttt12 = np.zeros([nr12+2, ny12, nx12])
ttt12[1:-1, :, :] = tmpocn[nr12*2:nr12*3, :, :] * hC12
ttt12[0, :, :] = ttt12[1, :, :]
ttt12[-1, :, :] = ttt12[-2, :, :]
ttt12_z75 = np.zeros([nr50, ny12, nx12])
#- verti interpolation -
# find last wet point and add repeat it downward for constant interpolation
for jjj in range(ny12):
  for iii in range(nx12):
    #- find last wet point and repeat it downward for constant interpolation -
    tmpk = np.where(ttt12[:, jjj, iii] == 0.0 )[0]
    if tmpk.size > 0:
     if (tmpk[0] > 0 and tmpk[0] < (nr12+1) ):
      ttt12[tmpk[0]:, jjj, iii] = ttt12[tmpk[0]-1, jjj, iii]
    #- vertical interpolation -
    f = interp1d(zzz12, ttt12[:, jjj, iii])
    ttt12_z75[:, jjj, iii] = f(rC50[:, 0, 0])
#- hz interp -
ttt50 = np.zeros([nr50, ny50, nx50])
for kkk in range(nr50):
  print('level: %03i' % kkk)
  ttt50[kkk, :, :] = griddata(xy12, ttt12_z75[kkk, :, :].reshape([ny12*nx12]), (xC50, yC50), method='linear')
#- save -
f = open( str("%s/t_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
ttt50.reshape([nr50*ny50*nx50]).astype('>f4').tofile(f)
f.close()

#-- salinity --
sss12 = np.zeros([nr12+2, ny12, nx12])
sss12[1:-1, :, :] = tmpocn[nr12*3:nr12*4, :, :] * hC12
sss12[0, :, :] = sss12[1, :, :]
sss12[-1, :, :] = sss12[-2, :, :]
sss12_z75 = np.zeros([nr50, ny12, nx12])
#- verti interpolation -
# find last wet point and add repeat it downward for constant interpolation
for jjj in range(ny12):
  for iii in range(nx12):
    #- find last wet point and repeat it downward for constant interpolation -
    tmpk = np.where(sss12[:, jjj, iii] == 0.0 )[0]
    if tmpk.size > 0:
     if (tmpk[0] > 0 and tmpk[0] < (nr12+1) ):
      sss12[tmpk[0]:, jjj, iii] = sss12[tmpk[0]-1, jjj, iii]
    #- vertical interpolation -
    f = interp1d(zzz12, sss12[:, jjj, iii])
    sss12_z75[:, jjj, iii] = f(rC50[:, 0, 0])
#- hz interp -
sss50 = np.zeros([nr50, ny50, nx50])
for kkk in range(nr50):
  print('level: %03i' % kkk)
  sss50[kkk, :, :] = griddata(xy12, sss12_z75[kkk, :, :].reshape([ny12*nx12]), (xC50, yC50), method='linear')
#- save -
f = open( str("%s/s_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
sss50.reshape([nr50*ny50*nx50]).astype('>f4').tofile(f)
f.close()

#-- uvel --
uuu12 = np.zeros([nr12+2, ny12, nx12])
uuu12[1:-1, :, :] = tmpocn[:nr12, :, :] * hW12
uuu12[0, :, :] = uuu12[1, :, :]
uuu12[-1, :, :] = uuu12[-2, :, :]
var12_z75 = np.zeros([nr50, ny12, nx12])
#- verti interpolation -
for jjj in range(ny12):
  for iii in range(nx12):
    f = interp1d(zzz12, uuu12[:, jjj, iii])
    var12_z75[:, jjj, iii] = f(rC50[:, 0, 0])
#- hz interp (with parallelization) -
if __name__ == '__main__':
  p = Pool(nproc)
  tmp_var50 = p.map(hz_interp, np.arange(nr50))
#- reshape -
uuu50 = np.zeros([nr50, ny50, nx50])
for kkk in range(nr50):
  uuu50[kkk, :, :] = tmp_var50[kkk]
#- save -
f = open( str("%s/u_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
uuu50.reshape([nr50*ny50*nx50]).astype('>f4').tofile(f)
f.close()

#-- vvel --
vvv12 = np.zeros([nr12+2, ny12, nx12])
vvv12[1:-1, :, :] = tmpocn[nr12:nr12*2, :, :] * hS12
vvv12[0, :, :] = vvv12[1, :, :]
vvv12[-1, :, :] = vvv12[-2, :, :]
var12_z75 = np.zeros([nr50, ny12, nx12])
#- verti interpolation -
for jjj in range(ny12):
  for iii in range(nx12):
    f = interp1d(zzz12, vvv12[:, jjj, iii])
    var12_z75[:, jjj, iii] = f(rC50[:, 0, 0])
#- hz interp -
vvv50 = np.zeros([nr50, ny50, nx50])
for kkk in range(nr50):
  print('level: %03i' % kkk)
  vvv50[kkk, :, :] = griddata(xy12, var12_z75[kkk, :, :].reshape([ny12*nx12]), (xC50, yC50), method='cubic')
#- save -
f = open( str("%s/v_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
vvv50.reshape([nr50*ny50*nx50]).astype('>f4').tofile(f)
f.close()


