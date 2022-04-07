import numpy as np
import MITgcmutils as mit
#import matplotlib.pyplot as plt
import os
import gc
from scipy.interpolate import griddata
from scipy.interpolate import interp1d
from multiprocessing import Pool

#plt.ion()

#-- directories --
dir_grd12 = '/glade/p/univ/ufsu0011/runs/gridMIT_update1/'
dir_grd50 = '/glade/p/univ/ufsu0011/runs/chao50/gridMIT/'
dir_in  = '/glade/p/univ/ufsu0011/runs/orar/memb00'
dir_out = '/glade/p/univ/ufsu0011/data_in/bound_cond_50'

#-- some parameters --
nt = 73		#also need earlier and past year for interpolation, 
		#for now it is coded in a 'normal year' fashion
nproc = 36      #number of processors used for parallelization 

#-- time param for loading --
dt = 200		#1/12 model time step
spy = 86400*365
dump = 5*86400       #5-d dumps
d_iter = dump/dt
nDump = spy/dump;

#-- grid params --
# hz grid: defined in lat/lon for indexing, 
#          but in [m] with co-localized origin for interpolation
rSphere = 6370000.0
#- 1/12 -
rC12 = mit.rdmds(dir_grd12 + 'RC')
rF12 = mit.rdmds(dir_grd12 + 'RF')
[nr12] = rC12[:, 0, 0].shape
xx12 = mit.rdmds(dir_grd12 + 'XC')
[ny12, nx12]  = xx12.shape
zzz12 = np.zeros([nr12+2])
zzz12[1:-1] = rC12[:, 0, 0]
zzz12[-1] = rF12[-1, 0, 0]
#- 1/50 -
rC50 = mit.rdmds(dir_grd50 + 'RC')
[nr50] = rC50[:, 0, 0].shape
xx50 = mit.rdmds(dir_grd50 + 'XC')
[ny50, nx50]  = xx50.shape

#-- variables and boundaries --
varN = ['t', 's', 'uE', 'vN']	
nvar = len(varN)
varOrder = [0, 1, 2, 3]		#Ordering of variables in diagnostic used to make obcs
bbdy = ['south', 'north', 'east', 'west']
nnbdy = len(bbdy)


#-----------------------------------------------------
# Define horizontal and vertical interpolation methods 
#-----------------------------------------------------

def interp_obcs(tttt):
  #print("-- tt=%02i || Interpolate %s at bdy %s --" % (tttt, varN[ivar], bbdy[ibdy]))
  tmpvarin = var12[tttt, :, :, :].reshape([nr12, ny2*nx2])
  #- hz interp -
  tmpvar = np.zeros([nr12+2, nxy50])
  for kkk in range(nr12):
    tmpvar[kkk+1] = griddata(xy12, tmpvarin[kkk, :], (xx50, yy50), method=mmeth)
  tmpvar[0, :] = tmpvar[1, :]
  tmpvar[-1, :] = tmpvar[-2, :]
  #- vert interp -
  tmpvar2 = np.zeros([nr50, nxy50])
  for ij in range(nxy50):
    # FOR TRACER ONLY
    # find last wet point and repeat it downward for constant interpolation 
    if varN[ivar] == 't' or varN[ivar] == 's':
      tmpk = np.where( tmpvar[:, ij] == 0.0 )[0]
      if tmpk.size > 0:
        if (tmpk[0] > 0 and tmpk[0] < (nr12+1) ):
          tmpvar[tmpk[0]:, ij] = tmpvar[tmpk[0]-1, ij]
    #
    f = interp1d(zzz12, tmpvar[:, ij])
    tmpvar2[:, ij] = f(rC50[:, 0, 0])
  return tmpvar2

#------------------------------------------------------------------
#	Make Boundary conditions from our previous 1/12 runs
#------------------------------------------------------------------

iper = 2003
offset = int((iper-1958)*spy/dt)
iters = np.arange(d_iter, (nDump+1)*d_iter, d_iter, dtype='int') + offset
tmpdir = str('%s/%04i' % (dir_out, iper))
if not os.path.isdir(tmpdir):
  os.makedirs( tmpdir )

#-- Loop over variables and boundaries --
for ivar in range(nvar):
  if varN[ivar] == 'uE':
    flag_repz = False	#to repeat grid points downward for vert. interp
    mmeth = 'cubic'	#interpolation method
    # 1/50
    x50deg = mit.rdmds(dir_grd50 + 'XG')
    y50deg = mit.rdmds(dir_grd50 + 'YC')
    hFac50 = mit.rdmds(dir_grd50 + 'hFacW')
    # 1/12
    x12deg = mit.rdmds(dir_grd12 + 'XG')
    y12deg = mit.rdmds(dir_grd12 + 'YC')
  elif varN[ivar] == 'vN':
    flag_repz = False	#to repeat grid points downward for vert. interp
    mmeth = 'cubic'	#interpolation method
    # 1/50
    x50deg = mit.rdmds(dir_grd50 + 'XC')
    y50deg = mit.rdmds(dir_grd50 + 'YG')
    hFac50 = mit.rdmds(dir_grd50 + 'hFacS')
    # 1/12
    x12deg = mit.rdmds(dir_grd12 + 'XC')
    y12deg = mit.rdmds(dir_grd12 + 'YG')
  else:		# tracers
    flag_repz = True	#to repeat grid points downward for vert. interp
    mmeth = 'linear'	#interpolation method
    # 1/50
    x50deg = mit.rdmds(dir_grd50 + 'XC')
    y50deg = mit.rdmds(dir_grd50 + 'YC')
    hFac50 = mit.rdmds(dir_grd50 + 'hFacC')
    # 1/12
    x12deg = mit.rdmds(dir_grd12 + 'XC')
    y12deg = mit.rdmds(dir_grd12 + 'YC')
  # define associated grid in [m] with co-localized origin
  tmpx50 = np.radians(x50deg - x50deg[0,0]) * rSphere * np.cos(np.radians(y50deg))
  tmpy50 = np.radians(y50deg - y50deg[0,0]) * rSphere
  tmpx12 = np.radians(x12deg - x50deg[0,0]) * rSphere * np.cos(np.radians(y12deg))
  tmpy12 = np.radians(y12deg - y50deg[0,0]) * rSphere
  # need to be consistent with ordering in bbdy
  [sbdy, nbdy, wbdy, ebdy] = [y50deg.min(), y50deg.max(), x50deg.min(), x50deg.max()]
  #
  for ibdy in range(nnbdy):
    print("== Deal with %s at bdy %s ==" % (varN[ivar], bbdy[ibdy]) )
    #
    #-- boundary parameters --
    deltaxy = 3	#+/- deltaxy grid points (on the 1/12 grid) around boundary
    if bbdy[ibdy] == 'south':
      #- 1/50 -
      if varN[ivar] == 'vN': #obcs are applied at inner grid points
        msk50 = hFac50[:, 1, :] 
        xx50 = tmpx50[1, :]
        yy50 = tmpy50[1, :]
      else:
        msk50 = hFac50[:, 0, :]
        xx50 = tmpx50[0, :]
        yy50 = tmpy50[0, :]
      nxy50 = nx50
      #-  associated subdomain on the 1/12 grid -
      iiw = np.where(x12deg[0,:]>wbdy)[0][0] - deltaxy
      iie = np.where(x12deg[0,:]>ebdy)[0][0] + deltaxy
      jjs = np.where(y12deg[:,0]>sbdy)[0][0] - deltaxy
      jjn = np.where(y12deg[:,0]>sbdy)[0][0] + deltaxy
    elif bbdy[ibdy] == 'north':
      #- 1/50 -
      msk50 = hFac50[:, -1, :]
      xx50 = tmpx50[-1, :]
      yy50 = tmpy50[-1, :]
      nxy50 = nx50
      #-  associated subdomain on the 1/12 grid -
      iiw = np.where(x12deg[0,:]>wbdy)[0][0] - deltaxy
      iie = np.where(x12deg[0,:]>ebdy)[0][0] + deltaxy
      jjs = np.where(y12deg[:,0]>nbdy)[0][0] - deltaxy
      jjn = np.where(y12deg[:,0]>nbdy)[0][0] + deltaxy
    elif bbdy[ibdy] == 'east':
      #- 1/50 -
      msk50 = hFac50[:, :, -1]
      xx50 = tmpx50[:, -1]
      yy50 = tmpy50[:, -1]
      nxy50 = ny50
      #-  associated subdomain on the 1/12 grid -
      iiw = np.where(x12deg[0,:]>ebdy)[0][0] - deltaxy
      iie = np.where(x12deg[0,:]>ebdy)[0][0] + deltaxy
      jjs = np.where(y12deg[:,0]>sbdy)[0][0] - deltaxy
      jjn = np.where(y12deg[:,0]>nbdy)[0][0] + deltaxy
    elif bbdy[ibdy] == 'west':
      #- 1/50 -
      if varN[ivar] == 'uE':
        msk50 = hFac50[:, :, 1]		#obcs are applied at inner grid points
        xx50 = tmpx50[:, 1]
        yy50 = tmpy50[:, 1]
      else:
        msk50 = hFac50[:, :, 0]
        xx50 = tmpx50[:, 0]
        yy50 = tmpy50[:, 0]
      nxy50 = ny50
      #-  associated subdomain on the 1/12 grid -
      iiw = np.where(x12deg[0,:]>wbdy)[0][0] - deltaxy
      iie = np.where(x12deg[0,:]>wbdy)[0][0] + deltaxy
      jjs = np.where(y12deg[:,0]>sbdy)[0][0] - deltaxy
      jjn = np.where(y12deg[:,0]>nbdy)[0][0] + deltaxy
    #
    #- adjuste 1/50 land mask -
    msk50[np.where(msk50 > 0.0)] = 1.0
    #- select 1/12 subdomain coordinates (in [m]) for interpolation -
    [ny2, nx2] = [jjn-jjs, iie-iiw]
    xy12 = np.zeros([(ny2)*(nx2), 2])
    xy12[:, 0] = tmpx12[jjs:jjn,iiw:iie].reshape([ny2*nx2])
    xy12[:, 1] = tmpy12[jjs:jjn,iiw:iie].reshape([ny2*nx2])
    #
    #-- horizontal interpolation --
    print('Loading 1/12 field ...')
    var12 = np.zeros([nt+2, nr12, ny2, nx2])
    var12[:-2, :, :, :] =  mit.rdmds( str("%s/run%04i/ocn/diag_ocnTave" \
            % (dir_in, iper) ), \
            itrs=list(iters), rec=varOrder[ivar], region=[iiw, iie, jjs, jjn], usememmap=True )
    #-- these lignes should be uncommented at some point to add the first (last) time record of 
    #   previous (next) year for a proper interpolation 
    #   (currently done in a 'normal year fashion)'--
    #var12[-1, :, :, :] =  mit.rdmds( str("%s/run%04i/ocn/diag_ocnTave" \
    #        % (dir_in, (iper-1)) ), \
    #        itrs=iters[0]-d_iter, rec=varOrder[ivar], region=[iiw, iie, jjs, jjn], usememmap=True )
    #var12[-2, :, :, :] =  mit.rdmds( str("%s/run%04i/ocn/diag_ocnTave" \
    #        % (dir_in, (iper+1)) ), \
    #        itrs=iters[-1]+d_iter, rec=varOrder[ivar], region=[iiw, iie, jjs, jjn], usememmap=True )
    var12[-1, :, :, :] = var12[0, :, :, :]
    var12[-2, :, :, :] = var12[-3, :, :, :]
    #- make some adjustments near land points (FOR TRACER ONLY) -
    if varN[ivar] == 't' or varN[ivar] == 's':
      for iit in range(nt+2):
        for kk in range(nr12):
          for jj in range(ny2):
            for ii in range(nx2-1, -1, -1):
              if var12[iit, kk, jj, ii] == 0.0:
                var12[iit, kk, jj, ii] = vlast
              else:
                vlast = var12[iit, kk, jj, ii]
    #- Interpolate (with parallelization) -
    if __name__ == '__main__':
      p = Pool(nproc)
      tmp_interp = p.map(interp_obcs, np.arange(nt+2))
    # reshape
    var50 = np.zeros([nt+2, nr50, nxy50])
    for iit in range(nt+2):
      var50[iit, :, :] = tmp_interp[iit].reshape([nr50, nxy50])
    #-- save --
    print('Save ...')
    f = open( str("%s/%s_%s_%04i.bin" % \
        (tmpdir, varN[ivar], bbdy[ibdy]  ,iper) ), 'wb')
    var50.reshape([(nt+2)*nr50*nxy50]).astype('>f4').tofile(f)
    f.close()
    #
    del var12, var50
    gc.collect()


exit()
