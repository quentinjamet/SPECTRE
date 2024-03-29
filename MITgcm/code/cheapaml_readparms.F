#include "CHEAPAML_OPTIONS.h"

      SUBROUTINE CHEAPAML_READPARMS( myThid )
C     *==========================================================*
C     | SUBROUTINE CHEAPAML_READPARMS                            |
C     | o Routine to initialize CHEAPAML variables and consts.   |
C     *==========================================================*
      IMPLICIT NONE

C     === Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "CHEAPAML.h"

C     === Routine arguments ===
      INTEGER myThid

C     === Local variables ===
C     msgBuf      :: Informational/error message buffer
C     iUnit       :: Work variable for IO unit number
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER iUnit
C-    retired parameters:
C     nRetired    :: Count number of "retired" parameters found in namelist.
      INTEGER nRetired
      _RL cheapaml_taurelax, cheapaml_taurelaxocean

C--   Bulk Formula parameter
      NAMELIST /CHEAPAML_CONST/
     &  cheapaml_ntim, cheapaml_mask_width,
     &  cheapaml_h, cheapaml_kdiff,
     &  cheap_tauRelax, cheap_tauRelaxOce,
     &  cdrag_1,cdrag_2,cdrag_3,
     &  rhoa, cpair, stefan, gasR, xkar,
     &   dsolms,dsolmn,zu,zt,zq,
     &   xphaseinit,gamma_blk,humid_fac,p0,
     &   cheap_pr1, cheap_pr2,
     &  cheapaml_taurelax, cheapaml_taurelaxocean

      NAMELIST /CHEAPAML_PARM01/
     &         periodicExternalForcing_cheap,
     &         useYearlyField_cheap,
     &         externForcingPeriod_cheap,
     &         externForcingCycle_cheap,
     &         AirTempFile,
     &         SolarFile,
     &         UWindFile,
     &         VWindFile,
     &         TrFile,
     &         QrFile,
     &         AirQFile,
     &         UStressFile, VStressFile,
     &         WaveHFile,WavePFile,
     &         TracerFile,TracerRfile,
     &         cheapMaskFile,cheap_hFile,
     &         cheap_clFile,cheap_dlwFile,
     &         cheap_prFile

      NAMELIST /CHEAPAML_PARM02/
     &         cheapamlXperiodic,
     &         cheapamlYperiodic,
     &         useFreshWaterFlux,
     &         useFluxLimit,
     &         FluxFormula,WaveModel,
     &         useStressOption,
     &         useCheapTracer ,
     &         useTimeVarBLH,
     &         useClouds,
     &         useDLongWave,
     &         usePrecip,
     &         useRelativeWind

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      IF ( .NOT.useCheapAML ) THEN
C-    pkg CHEAPAML is not used
        _BEGIN_MASTER(myThid)
C-    Track pkg activation status:
C     print a (weak) warning if data.cheapaml is found
         CALL PACKAGES_UNUSED_MSG( 'useCheapAML', ' ', ' ' )
        _END_MASTER(myThid)
        RETURN
      ENDIF

      _BEGIN_MASTER(myThid)

      WRITE(msgBuf,'(A)') ' BULKF_READPARMS: opening data.cheapaml'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

      CALL OPEN_COPY_DATA_FILE(
     I                          'data.cheapaml', 'CHEAPAML_READPARMS',
     O                          iUnit,
     I                          myThid )

C--   Hard-coded values (not in any namelist):
C     coeff. used to compute saturation specific humidity (not in namelist)
      ssq0 = 3.797915 _d 0
      ssq1 = 7.93252  _d -6
      ssq2 = 2.166847 _d -3

C--   Default values
C-    Physical constant :
      cheapaml_ntim = 5
      cheapaml_h=1000. _d 0
      cheapaml_kdiff=1. _d 4
      cheap_tauRelax    = 8640. _d 0
      cheap_tauRelaxOce = 0. _d 0
      cheapaml_mask_width = 0
      rhoa   = 1.3 _d 0
      cpair  = 1004. _d 0
      stefan = 5.67 _d -8
      dsolms = 50. _d 0
      dsolmn = 25. _d 0
C heights of variables
      zu=10. _d 0
      zt=zu
      zq=zu
      xphaseinit = 0. _d 0
      cdrag_1=0.0027 _d 0
      cdrag_2=0.000142 _d 0
      cdrag_3=0.0000764 _d 0
C gas constant
      gasR=287.04 _d 0
C atmospheric adiabatic lapse rate
      gamma_blk=0.0098 _d 0
C humidity factor for computing virtual potential temperature
      humid_fac=0.606 _d 0
C surface pressure in mb
      p0=1000. _d 0
C latent heat (J/kg)
      lath=2.5 _d 6
C von Karman constant
      xkar=0.4 _d 0
C periodic forcing
      periodicExternalForcing_cheap = periodicExternalForcing
      useYearlyField_cheap = useYearlyField
      externForcingPeriod_cheap = externForcingPeriod
      externForcingCycle_cheap = externForcingCycle
C precipitation time constant
      cheap_pr1 = 2*3600.0 _d 0
      cheap_pr2 = 36*3600.0 _d 0

C-    Retired parameters: initialised to unlikely value:
      nRetired = 0
      cheapaml_taurelax = UNSET_RL
      cheapaml_taurelaxocean = UNSET_RL

C-    Input data files names :
      AirTempFile=' '
      AirQFile=' '
      SolarFile=' '
      UWindFile=' '
      VWindFile=' '
      TrFile=' '
      QrFile=' '
      WaveHFile=' '
      WavePFile=' '
      TracerFile=' '
      TracerRFile=' '
      cheapMaskFile=' '
      cheap_hFile =' '
      cheap_prFile =' '
      cheap_clFile =' '
      cheap_dlwFile =' '
      FluxFormula='COARE3'
      WaveModel='Smith'

C-    Assumes domain (with land) is periodic in both direction
C      (consitent with default EXCH setting)
c     cheapamlXperiodic = .TRUE.
c     cheapamlYperiodic = .TRUE.
C note: for backward compatibility, switch to non periodic domain:
      cheapamlXperiodic = .FALSE.
      cheapamlYperiodic = .FALSE.

C-    e-p option turned off by default
      useFreshWaterFlux=.TRUE.

C-    turn off flux limiting advection by default
      useFluxLimit=.FALSE.

C-    turn off stress option by default
      useStressOption=.FALSE.

C-    turn off passive tracer option by default
      useCheapTracer=.FALSE.

C-    turn off time varying BL height option by default
      useTimeVarBLH=.FALSE.

C-    turn off clouds option by default
      useClouds=.FALSE.

C-    use imported downward longwave
      useDLongWave=.FALSE.

C-    use imported precip
      usePrecip=.FALSE.

C-    use relative wind
      useRelativeWind=.FALSE.

C--   Read parameters from open data file
      READ(UNIT=iUnit,NML=CHEAPAML_CONST)
      WRITE(msgBuf,'(A)') ' CHEAPAML_READPARMS: read CHEAPAML_CONST'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

C--   Read parameters from open data file
      READ(UNIT=iUnit,NML=CHEAPAML_PARM01)
      WRITE(msgBuf,'(A)') ' CHEAPAML_READPARMS: read CHEAPAML_PARM01'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

C--   Read parameters from open data file
      READ(UNIT=iUnit,NML=CHEAPAML_PARM02)
      WRITE(msgBuf,'(A)') ' CHEAPAML_READPARMS: read CHEAPAML_PARM02'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

C--   Close the open data file
#ifdef SINGLE_DISK_IO
      CLOSE(iUnit)
#else
      CLOSE(iUnit,STATUS='DELETE')
#endif /* SINGLE_DISK_IO */
C compute derivative values
C energy flux conversion factor
        xef=1. _d 0 /rhoa/cpair
C inverse of layer thickness
        hm=1. _d 0/cheapaml_h

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      iUnit = standardMessageUnit
      WRITE(iUnit,*) 'Caml: ntim     =',cheapaml_ntim
      WRITE(iUnit,*) 'Caml: mask_w   =',cheapaml_mask_width
      WRITE(iUnit,*) 'Caml: h        =',cheapaml_h
      WRITE(iUnit,*) 'Caml: kdiff    =',cheapaml_kdiff
      WRITE(iUnit,*) 'Caml: tauRelax =', cheap_tauRelax, ' (s)'
      WRITE(iUnit,*) 'Caml: tRelaxOce=', cheap_tauRelaxOce,' (s)'
      WRITE(iUnit,*) 'Caml: rhoa     =',rhoa
      WRITE(iUnit,*) 'Caml: cpair    =',cpair
      WRITE(iUnit,*) 'Caml: stefan   =',stefan
      WRITE(iUnit,*) 'Caml: cheapamlXperiodic  =',cheapamlXperiodic
      WRITE(iUnit,*) 'Caml: cheapamlYperiodic  =',cheapamlYperiodic
      WRITE(iUnit,*) 'Caml: useFreshWaterFlux  =',useFreshWaterFlux
      WRITE(iUnit,*) 'Caml: useFluxLimit       =',useFluxLimit
      WRITE(iUnit,*) 'Caml: useStressOption    =',useStressOption
      WRITE(iUnit,*) 'Caml: useCheapTracer     =',useCheapTracer
      WRITE(iUnit,*) 'Caml: useTimeVarBLH      =',useTimeVarBLH
      WRITE(iUnit,*) 'Caml: useClouds          =',useClouds
      WRITE(iUnit,*) 'Caml: useDlongwave       =',useDLongWave
      WRITE(iUnit,*) 'Caml: usePrecip          =',usePrecip
C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      IF ( cheapaml_taurelax .NE. UNSET_RL ) THEN
        nRetired = nRetired + 1
        WRITE(msgBuf,'(2A)')
     &   'S/R CHEAPAML_READPARMS: "cheapaml_taurelax" no longer'
        CALL PRINT_ERROR( msgBuf, myThid )
        WRITE(msgBuf,'(2A)')
     &   'S/R CHEAPAML_READPARMS:  allowed in file "data.cheapaml"'
        CALL PRINT_ERROR( msgBuf, myThid )
      ENDIF
      IF ( cheapaml_taurelaxocean .NE. UNSET_RL ) THEN
        nRetired = nRetired + 1
        WRITE(msgBuf,'(2A)')
     &   'S/R CHEAPAML_READPARMS: "cheapaml_taurelaxocean" no longer'
        CALL PRINT_ERROR( msgBuf, myThid )
        WRITE(msgBuf,'(2A)')
     &   'S/R CHEAPAML_READPARMS:  allowed in file "data.cheapaml"'
        CALL PRINT_ERROR( msgBuf, myThid )
      ENDIF

      IF ( nRetired .GT. 0 ) THEN
       WRITE(msgBuf,'(2A)') 'S/R CHEAPAML_READPARMS: ',
     &  'Error reading file "data.cheapaml":'
       CALL PRINT_ERROR( msgBuf, myThid )
       WRITE(msgBuf,'(I4,A)') nRetired,
     &      ' out-of-date parameters were found in the namelist(s)'
       CALL PRINT_ERROR( msgBuf, myThid )
c      errCount = errCount + 1
       CALL ALL_PROC_DIE( 0 )
       STOP 'ABNORMAL END: S/R CHEAPAML_READPARMS'
      ENDIF

      _END_MASTER(myThid)

C--   Everyone else must wait for the parameters to be loaded
      _BARRIER

      RETURN
      END
