#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: INTEGR_CONTINUITY
C     !INTERFACE:
      SUBROUTINE INTEGR_CONTINUITY(
     I                             uFld, vFld,
     I                             myTime, myIter, myThid )
C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE INTEGR_CONTINUITY
C     | o Integrate the continuity Eq : compute vertical velocity
C     |   and free surface "r-anomaly" (etaN,etaH) to satisfy
C     |   exactly the conservation of the Total Volume
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     == Global variables
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"
#include "SURFACE.h"
#include "FFIELDS.h"
#ifdef ALLOW_DIAGNOSTICS
#include "DIAGNOSTICS_EVAR.h"
#endif

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     uFld     :: Zonal velocity ( m/s )
C     vFld     :: Meridional velocity ( m/s )
C     myTime   :: Current time in simulation
C     myIter   :: Current iteration number in simulation
C     myThid   :: my Thread Id. number
      _RL myTime
      INTEGER myIter
      INTEGER myThid
      _RL uFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL vFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)

C     !LOCAL VARIABLES:
C     Local variables in common block

C     Local variables
C     bi,bj    :: tile index
C     i,j,k    :: Loop counters
C     uTrans   :: Volume transports ( uVel.xA )
C     vTrans   :: Volume transports ( vVel.yA )
C     hDivFlow :: Div. Barotropic Flow [transport unit m3/s]
      INTEGER k,bi,bj
#ifdef EXACT_CONSERV
      INTEGER i, j
      INTEGER ks
      _RL uTrans(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL vTrans(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL hDivFlow(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL facEmP, facMass
#else /* EXACT_CONSERV */
# ifdef ALLOW_OBCS
      INTEGER i, j
# endif
#endif /* EXACT_CONSERV */
#ifndef ALLOW_ADDFLUID
      _RL addMass(1)
#endif /* ndef ALLOW_ADDFLUID */
#if (defined NONLIN_FRSURF) && !(defined DISABLE_RSTAR_CODE)
      _RL rStarDhDt(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
#else
      _RL rStarDhDt(1)
#endif
#ifdef ALLOW_DIAGNOSTICS
      _RL tmpFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL tmpFac
      LOGICAL  DIAGNOSTICS_IS_ON
      EXTERNAL DIAGNOSTICS_IS_ON
#endif
CEOP

C--   Start bi,bj loops
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

#ifdef EXACT_CONSERV
      IF (exactConserv) THEN

       facEmP = 0.
       IF ( fluidIsWater.AND.useRealFreshWaterFlux ) facEmP=mass2rUnit
       facMass = 0.
       IF ( selectAddFluid.GE.1 ) facMass = mass2rUnit

C--   Compute the Divergence of The Barotropic Flow :

C-    Initialise
       DO j=1-OLy,sNy+OLy
        DO i=1-OLx,sNx+OLx
         hDivFlow(i,j)      = 0. _d 0
         utrans(i,j)        = 0. _d 0
         vtrans(i,j)        = 0. _d 0
        ENDDO
       ENDDO

       DO k=1,Nr

C-    Calculate velocity field "volume transports" through tracer cell faces
C     anelastic: uTrans,vTrans are scaled by rhoFacC (~ mass transport).
        DO j=1,sNy+1
         DO i=1,sNx+1
          uTrans(i,j) = uFld(i,j,k,bi,bj)*_dyG(i,j,bi,bj)
     &                 *deepFacC(k)*rhoFacC(k)
     &                 *drF(k)*_hFacW(i,j,k,bi,bj)
          vTrans(i,j) = vFld(i,j,k,bi,bj)*_dxG(i,j,bi,bj)
     &                 *deepFacC(k)*rhoFacC(k)
     &                 *drF(k)*_hFacS(i,j,k,bi,bj)
         ENDDO
        ENDDO

C-    Integrate vertically the Horizontal Divergence
        DO j=1,sNy
         DO i=1,sNx
           hDivFlow(i,j) = hDivFlow(i,j)
     &       +maskC(i,j,k,bi,bj)*( uTrans(i+1,j)-uTrans(i,j)
     &                            +vTrans(i,j+1)-vTrans(i,j) )
#ifdef ALLOW_ADDFLUID
     &       -facMass*addMass(i,j,k,bi,bj)
#endif /* ALLOW_ADDFLUID */
         ENDDO
        ENDDO

C-    End DO k=1,Nr
       ENDDO

C------------------------------------
C note: deep-model not implemented for P-coordinate + realFreshWaterFlux ;
C       anelastic: always assumes that rhoFacF(1) = 1
       IF ( myIter.EQ.nIter0 .AND. myIter.NE.0
     &    .AND. fluidIsWater .AND. useRealFreshWaterFlux ) THEN

C     needs previous time-step value of E-P-R, that has not been loaded
C     and was not in old pickup-file ; try to use etaN & etaH instead.
         IF ( usePickupBeforeC54 ) THEN
          DO j=1,sNy
           DO i=1,sNx
            dEtaHdt(i,j,bi,bj) = (etaN(i,j,bi,bj)-etaH(i,j,bi,bj))
     &                         / (implicDiv2Dflow*deltaTfreesurf)
           ENDDO
          ENDDO
         ENDIF

         DO j=1,sNy
          DO i=1,sNx
            PmEpR(i,j,bi,bj) = dEtaHdt(i,j,bi,bj)
     &                       + hDivFlow(i,j)*recip_rA(i,j,bi,bj)
     &                                      *recip_deepFac2F(1)
            PmEpR(i,j,bi,bj) = PmEpR(i,j,bi,bj)*rUnit2mass
          ENDDO
         ENDDO
       ELSEIF ( myIter.EQ.nIter0 ) THEN
         DO j=1,sNy
          DO i=1,sNx
            ks = kSurfC(I,J,bi,bj)
            PmEpR(i,j,bi,bj) = 0. _d 0
            dEtaHdt(i,j,bi,bj) = -hDivFlow(i,j)*recip_rA(i,j,bi,bj)
     &                                         *recip_deepFac2F(ks)
          ENDDO
         ENDDO
       ELSE
C--    Needs to get valid PmEpR (for T,S forcing) also in overlap regions
C       (e.g., if using KPP) => set over full index range
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
            PmEpR(i,j,bi,bj) = -EmPmR(i,j,bi,bj)
          ENDDO
         ENDDO
         DO j=1,sNy
          DO i=1,sNx
            ks = kSurfC(i,j,bi,bj)
            dEtaHdt(i,j,bi,bj) = -hDivFlow(i,j)*recip_rA(i,j,bi,bj)
     &                                         *recip_deepFac2F(ks)
     &                           -facEmP*EmPmR(i,j,bi,bj)
          ENDDO
         ENDDO
       ENDIF
C------------------------------------

#ifdef ALLOW_OBCS
C--    reset dEtaHdt to zero outside the OB interior region
       IF ( useOBCS ) THEN
         DO j=1,sNy
          DO i=1,sNx
            dEtaHdt(i,j,bi,bj) = dEtaHdt(i,j,bi,bj)*maskInC(i,j,bi,bj)
          ENDDO
         ENDDO
       ENDIF
#endif /* ALLOW_OBCS */

C-- end if exactConserv block
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      IF ( exactConserv .AND. myIter.NE.nIter0 ) THEN
C--   Update etaN at the end of the time step :
C     Incorporate the Implicit part of -Divergence(Barotropic_Flow)

       IF (implicDiv2Dflow.EQ. 0. _d 0) THEN
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
           etaN(i,j,bi,bj) = etaH(i,j,bi,bj)
         ENDDO
        ENDDO
       ELSE
        DO j=1,sNy
         DO i=1,sNx
           etaN(i,j,bi,bj) = etaH(i,j,bi,bj)
     &      + implicDiv2Dflow*dEtaHdt(i,j,bi,bj)*deltaTfreesurf
         ENDDO
        ENDDO
       ENDIF

#ifdef ALLOW_OBCS
C--    Was added on Dec 30, 2004 (to fix unrealistic etaN ?), but no longer
C      needed with proper masking in solver (matrix+cg2d_b,x) and masking
C      of dEtaHdt above. etaN next to OB does not enter present algorithm but
C      leave it commented out in case we would implement an aternative scheme.
c      IF ( useOBCS ) CALL OBCS_APPLY_ETA( bi, bj, etaN, myThid )
#endif /* ALLOW_OBCS */

C-- end if exactConserv and not myIter=nIter0 block
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

# ifdef NONLIN_FRSURF
      IF (select_rStar .NE. 0) THEN
#  ifndef DISABLE_RSTAR_CODE
C-- note: rStarDhDt is similar to rStarDhCDt from S/R CALC_R_STAR
C         except for deep-factor and rho factor.
        DO j=1,sNy
         DO i=1,sNx
           ks = kSurfC(i,j,bi,bj)
           rStarDhDt(i,j) = dEtaHdt(i,j,bi,bj)
     &                     *deepFac2F(ks)*rhoFacF(ks)
     &                     *recip_Rcol(i,j,bi,bj)
         ENDDO
        ENDDO
#  endif /* DISABLE_RSTAR_CODE */
      ENDIF
# endif /* NONLIN_FRSURF */

#endif /* EXACT_CONSERV */

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      DO k=Nr,1,-1
C--    Integrate continuity vertically for vertical velocity

       CALL INTEGRATE_FOR_W(
     I                       bi, bj, k, uFld, vFld,
     I                       addMass, rStarDhDt,
     O                       wVel,
     I                       myThid )

#ifdef EXACT_CONSERV
       IF ( k.EQ.Nr .AND. myIter.NE.0 .AND. usingPCoords
     &      .AND. fluidIsWater .AND. useRealFreshWaterFlux ) THEN

         DO j=1,sNy
          DO i=1,sNx
            wVel(i,j,k,bi,bj) = wVel(i,j,k,bi,bj)
     &               +mass2rUnit*PmEpR(i,j,bi,bj)*maskC(i,j,k,bi,bj)
          ENDDO
         ENDDO

       ENDIF
#endif /* EXACT_CONSERV */

#ifdef ALLOW_OBCS
C--    reset W to zero outside the OB interior region
       IF ( useOBCS ) THEN
         DO j=1,sNy
          DO i=1,sNx
             wVel(i,j,k,bi,bj) = wVel(i,j,k,bi,bj)*maskInC(i,j,bi,bj)
          ENDDO
         ENDDO
       ENDIF
C--    Apply OBC to W (non-hydrostatic):
       IF ( useOBCS.AND.nonHydrostatic )
     &                CALL OBCS_APPLY_W( bi, bj, k, wVel, myThid )
#endif /* ALLOW_OBCS */

C-    End DO k=Nr,1,-1
      ENDDO

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   End bi,bj loops
       ENDDO
      ENDDO

      IF ( exactConserv .AND. myIter.NE.nIter0
     &                  .AND. implicDiv2Dflow .NE. 0. _d 0 )
     &    _EXCH_XY_RL( etaN , myThid )
      IF ( implicitIntGravWave .OR. myIter.EQ.nIter0 )
     &    _EXCH_XYZ_RL( wVel , myThid )

#ifdef EXACT_CONSERV
C--   Update etaH (from etaN and dEtaHdt):
      IF (exactConserv) THEN
c       IF ( useRealFreshWaterFlux .AND. myIter.EQ.nIter0 )
c    &    _EXCH_XY_RL( PmEpR, myThid )
#ifdef ALLOW_DEBUG
        IF (debugMode) CALL DEBUG_CALL('UPDATE_ETAH',myThid)
#endif
        CALL UPDATE_ETAH( myTime, myIter, myThid )
      ENDIF

#ifdef NONLIN_FRSURF
# ifndef DISABLE_SIGMA_CODE
      IF ( nonlinFreeSurf.GT.0 .AND. selectSigmaCoord.NE.0 ) THEN
        CALL EXCH_XY_RL( dEtaHdt, myThid )
        CALL UPDATE_ETAWS( myTime, myIter, myThid )
      ENDIF
# endif /* DISABLE_SIGMA_CODE */
#endif /* NONLIN_FRSURF */

#endif /* EXACT_CONSERV */

#ifdef ALLOW_DIAGNOSTICS
      IF (witer0) THEN
      IF ( DIAGNOSTICS_IS_ON('WRHOMAS2',myThid) ) THEN
        tmpFac = 0.5 _d 0
       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         DO k=1,Nr
          IF ( k.EQ.1 ) THEN
           DO j=1,sNy
            DO i=1,sNx
             tmpFld(i,j) = wVel(i,j,k,bi,bj)*rho_sav(i,j,k,bi,bj)
            ENDDO
           ENDDO
          ELSE
           DO j=1,sNy
            DO i=1,sNx
             tmpFld(i,j) = wVel(i,j,k,bi,bj)
     &                   *(rho_sav(i,j,k-1,bi,bj)+rho_sav(i,j,k,bi,bj))
     &                   *0.5 _d 0
            ENDDO
           ENDDO
          ENDIF
          CALL DIAGNOSTICS_SCALE_FILL(tmpFld, tmpFac, 1,
     &       'WRHOMAS2',k,1,-1,bi,bj,myThid)
         ENDDO
        ENDDO
       ENDDO
      ENDIF
      ELSE
        witer0 = .TRUE.
      ENDIF
#endif /* ALLOW_DIAGNOSTICS */

      RETURN
      END
