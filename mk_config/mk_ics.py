import numpy as np
import MITgcmutils as mit
import matplotlib.pyplot as plt
import xarray as xr
import os
from scipy.interpolate import griddata
from scipy.interpolate import interp1d
from multiprocessing import Pool

plt.ion()

#-- directories --
dir_grd12 = '/glade/p/univ/ufsu0011/runs/gridMIT_update1/'
dir_grd50 = '/glade/p/univ/ufsu0011/runs/chao50/gridMIT/'
dir_ic12  = '/glade/p/univ/ufsu0011/data_in/ini_cond_12/ensemble_ic'
dir_ic50  = '/glade/p/univ/ufsu0011/data_in/ini_cond_50'

dir_fig = '/tank/chaocean/scripts_py/chao50/'
#-- some parameters --
[nr12, ny12, nx12] = [46, 900, 1000]
iiter = 946080

varN = ['u', 'v', 't', 's']
nvar = len(varN)
# varNb shoudl match pickup fil ordering
# 'Uvel    ' 'Vvel    ' 'Theta   ' 'Salt    ' 'GuNm1   ' 'GvNm1   ' 'EtaN    ' 'dEtaHdt ' 'EtaH    '
varNb = [0, 1, 2, 3]

#------------------------------------------------------------------
#	Make Initial conditions from our previous 1/12 runs
#------------------------------------------------------------------

#-- grid params --
#- 1/12 -
xC12 = mit.rdmds(dir_grd12 + 'XC')
yC12 = mit.rdmds(dir_grd12 + 'YC')
xy12 = np.zeros([(ny12)*(nx12), 2])
xy12[:, 0] = xC12.reshape([ny12*nx12])
xy12[:, 1] = yC12.reshape([ny12*nx12])
rC12 = mit.rdmds(dir_grd12 + 'RC')
rF12 = mit.rdmds(dir_grd12 + 'RF')
zzz12 = np.zeros([nr12+2])
zzz12[1:-1] = rC12[:, 0, 0]
zzz12[-1] = rF12[-1, 0, 0]
hC12 = mit.rdmds(dir_grd12 + 'hFacC')
hS12 = mit.rdmds(dir_grd12 + 'hFacS')
hW12 = mit.rdmds(dir_grd12 + 'hFacW')
#- 1/50 -
xC50 = mit.rdmds(dir_grd50 + 'XC')
yC50 = mit.rdmds(dir_grd50 + 'YC')
rC50 = mit.rdmds(dir_grd50 + 'RC')
[ny50, nx50] = xC50.shape
nr50 = len(rC50[:, 0,0])

#-- pre-loading -- 
iic = 000
tmpdir = str('%s/ic%03i' % (dir_ic50, iic))
if not os.path.isdir(tmpdir):
  os.mkdir( tmpdir )
#- from pickups -
tmpocn = mit.rdmds( str('%s/ic%02i/pickup.%010i' % (dir_ic12, iic, iiter)) )

#-- define horizontal interpolation --
nproc = 36      #number of processors used for parallelization
def hz_interp(kkkk):
  print("Interpolating %s, level k=%03i" % (varN[ivar], kkkk) )
  tmp_interp = griddata(xy12, var12_z75[kkkk, :, :].reshape([ny12*nx12]), (xC50, yC50), method='linear')
  return tmp_interp


#-- interpolatte --
for ivar in range(nvar):
  #ivar = 0
  if varN[ivar] == 'u':
    hFac12 = hW12
  elif varN[ivar] == 'v':
    hFac12 = hS12
  else:
    hFac12 = hC12
  var12 = np.zeros([nr12+2, ny12, nx12])
  var12[1:-1, :, :] = tmpocn[varNb[ivar]*nr12:(varNb[ivar]+1)*nr12, :, :] * hFac12
  var12[0, :, :] = var12[1, :, :]
  var12[-1, :, :] = var12[-2, :, :]
  var12_z75 = np.zeros([nr50, ny12, nx12])
  #- vert interpolation -
  for jjj in range(ny12):
    for iii in range(nx12):
      # FOR TRACER ONLY
      # find last wet point and repeat it downward for constant interpolation -
      if varN[ivar] == 't' or varN[ivar] == 's':
        tmpk = np.where(var12[:, jjj, iii] == 0.0 )[0]
        if tmpk.size > 0:
          if (tmpk[0] > 0 and tmpk[0] < (nr12+1) ):
            var12[tmpk[0]:, jjj, iii] = var12[tmpk[0]-1, jjj, iii]
      #
      f = interp1d(zzz12, var12[:, jjj, iii])
      var12_z75[:, jjj, iii] = f(rC50[:, 0, 0])
  #- hz interp (with parallelization) -
  if __name__ == '__main__':
    p = Pool(nproc)
    tmp_var50 = p.map(hz_interp, np.arange(nr50))
  #- reshape -
  var50 = np.zeros([nr50, ny50, nx50])
  for kkk in range(nr50):
    var50[kkk, :, :] = tmp_var50[kkk]
  #- save -
  f = open( str("%s/%s_ini50_ic%03i.bin" %(tmpdir, varN[ivar], iic) ), 'wb')
  var50.astype('>f4').tofile(f)
  f.close()
  #
  del var12, var12_z75, var50

#-----------------------------------
# Surface fields (Eta, t2,q2)
#-----------------------------------
#-- eta --
print('-- interpolate eta --')
eta12 = tmpocn[nr12*6, :, :] * hC12[0, :, :]
#- hz interp -
eta50 = griddata(xy12, eta12.reshape([ny12*nx12]), (xC50, yC50), method='linear')
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
t2_50 = griddata(xy12, t2_12.reshape([ny12*nx12]), (xC50, yC50), method='linear')
#- save -
f = open( str("%s/t2_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
t2_50.reshape([ny50*nx50]).astype('>f4').tofile(f)
f.close()
print('-- interpolate q2 (cheapaml) --')
#-- atmospheric q2 --
q2_12 = tmpcheap[2, :, :]
#- hz interp -
q2_50 = griddata(xy12, q2_12.reshape([ny12*nx12]), (xC50, yC50), method='linear')
#- save -
f = open( str("%s/q2_ini50_ic%03i.bin" %(tmpdir, iic) ), 'wb')
q2_50.reshape([ny50*nx50]).astype('>f4').tofile(f)
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


