#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: CORRECTION_STEP
C     !INTERFACE:
      SUBROUTINE CORRECTION_STEP( bi, bj, iMin, iMax, jMin, jMax,
     I                      phiSurfX, phiSurfY,
     I                      myTime, myIter, myThid )
C     !DESCRIPTION: \bv
C     *==========================================================*
C     | S/R CORRECTION_STEP
C     | o Corrects the horizontal flow fields with the surface
C     |   pressure (and Non-Hydrostatic pressure).
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     == Global variables ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "DYNVARS.h"
#ifdef ALLOW_NONHYDROSTATIC
#include "NH_VARS.h"
#endif
#include "DIAGNOSTICS_EVAR.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine Arguments ==
C     bi, bj              :: Tile indices
C     iMin,iMax,jMin,jMax :: Loop counters range
C     phiSurfX, phiSurfY  :: Surface Potential gradient
C     myTime              :: Current time in simulation
C     myIter              :: Current iteration number in simulation
C     myThid              :: my Thread Id number
      _RL     phiSurfX(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL     phiSurfY(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      INTEGER bi, bj
      INTEGER iMin, iMax, jMin, jMax
      _RL     myTime
      INTEGER myIter
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     i, j         :: Loop counters
C     k            :: Level index
C     psFac, nhFac :: Scaling parameters for supressing gradients
C     gU_dpx       :: implicit part of pressure gradient tendency
C     gV_dpy       :: implicit part of pressure gradient tendency
      INTEGER i,j
      INTEGER k
      _RL     psFac, nhFac
      _RL     gU_dpx(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL     gV_dpy(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
#ifdef ALLOW_DIAGNOSTICS
      LOGICAL     DIAGNOSTICS_IS_ON
      EXTERNAL    DIAGNOSTICS_IS_ON
      _RL tmpU (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL tmpV (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL tmpKE (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL uvel0 (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL vvel0 (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL tmpFac
#endif
CEOP

C--   Loop over all layers, top to bottom
      DO k=1,Nr

#ifdef ALLOW_SOLVE4_PS_AND_DRAG
       IF ( selectImplicitDrag.EQ.2 ) THEN

C     On/off scaling parameter
        psFac = pfFacMom*implicSurfPress

C     Pressure gradient tendency (zonal mom): Implicit part
        DO j=jMin,jMax
         DO i=iMin,iMax
          gU_dpx(i,j) =
     &         -psFac*dU_psFacX(i,j,k,bi,bj)*phiSurfX(i,j)
c    &                  *_maskW(i,j,k,bi,bj)
         ENDDO
        ENDDO

C     Pressure gradient tendency (merid mom): Implicit part
        DO j=jMin,jMax
         DO i=iMin,iMax
          gV_dpy(i,j) =
     &         -psFac*dV_psFacY(i,j,k,bi,bj)*phiSurfY(i,j)
c    &                  *_maskS(i,j,k,bi,bj)
         ENDDO
        ENDDO

       ELSE
#endif /* ALLOW_SOLVE4_PS_AND_DRAG */

C     On/off scaling parameters (including anelastic & deep-model factors)
        psFac = pfFacMom*implicSurfPress
     &         *recip_deepFacC(k)*recip_rhoFacC(k)
        IF ( use3Dsolver ) THEN
         nhFac = pfFacMom*implicitNHPress
     &          *recip_deepFacC(k)*recip_rhoFacC(k)
        ELSE
         nhFac = 0.
        ENDIF

C     Pressure gradient tendency (zonal mom): Implicit part
        DO j=jMin,jMax
         DO i=iMin,iMax
          gU_dpx(i,j) = -(
     &          psFac*phiSurfX(i,j)
#ifdef ALLOW_NONHYDROSTATIC
     &        + nhFac*_recip_dxC(i,j,bi,bj)
     &           *(phi_nh(i,j,k,bi,bj)-phi_nh(i-1,j,k,bi,bj))
#endif
     &                   )*_maskW(i,j,k,bi,bj)
         ENDDO
        ENDDO

C     Pressure gradient tendency (merid mom): Implicit part
        DO j=jMin,jMax
         DO i=iMin,iMax
          gV_dpy(i,j) = -(
     &          psFac*phiSurfY(i,j)
#ifdef ALLOW_NONHYDROSTATIC
     &        + nhFac*_recip_dyC(i,j,bi,bj)
     &           *(phi_nh(i,j,k,bi,bj)-phi_nh(i,j-1,k,bi,bj))
#endif
     &                   )*_maskS(i,j,k,bi,bj)
         ENDDO
        ENDDO

#ifdef ALLOW_SOLVE4_PS_AND_DRAG
       ENDIF
#endif /* ALLOW_SOLVE4_PS_AND_DRAG */

#ifdef ALLOW_DIAGNOSTICS
       DO j=jMin,jMax
        DO i=iMin,iMax
          uvel0(i,j) = uVel(i,j,k,bi,bj)
          vvel0(i,j) = vVel(i,j,k,bi,bj)
        ENDDO
       ENDDO
#endif

C     Update zonal velocity: add implicit pressure gradient tendency
       DO j=jMin,jMax
        DO i=iMin,iMax
          uVel(i,j,k,bi,bj)=( gU(i,j,k,bi,bj)
     &                      + deltaTMom*gU_dpx(i,j)
     &                      )*_maskW(i,j,k,bi,bj)
#ifdef ALLOW_OBCS
     &                       *maskInW(i,j,bi,bj)
#endif
        ENDDO
       ENDDO

C     Update merid. velocity: add implicit pressure gradient tendency
       DO j=jMin,jMax
        DO i=iMin,iMax
          vVel(i,j,k,bi,bj)=( gV(i,j,k,bi,bj)
     &                      + deltaTMom*gV_dpy(i,j)
     &                      )*_maskS(i,j,k,bi,bj)
#ifdef ALLOW_OBCS
     &                       *maskInS(i,j,bi,bj)
#endif
        ENDDO
       ENDDO

#ifdef ALLOW_DIAGNOSTICS
       IF ( useDiagnostics ) THEN
        CALL DIAGNOSTICS_FILL( gU_dpx,
     &                         'Um_dEdx ', k, 1, 2, bi, bj, myThid )
        CALL DIAGNOSTICS_FILL( gV_dpy,
     &                         'Vm_dEdy ', k, 1, 2, bi, bj, myThid )
       ENDIF

C -- energy diagnostics
       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('UUm_dEdx',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_dEg ',myThid) ) ) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
            tmpU(i,j) = 0.5 _d 0*(uvel0(i,j)+uVel(i,j,k,bi,bj))
     &          *gU_dpx(i,j)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpU,'UUm_dEdx', k ,1, 2,bi,bj, myThid)
       ENDIF

       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('VVm_dEdy',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_dEg ',myThid) ) ) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpV(i,j) = 0.5 _d 0*(vvel0(i,j)+vVel(i,j,k,bi,bj))
     &          *gV_dpy(i,j)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpV,'VVm_dEdy', k ,1, 2,bi,bj, myThid)
       ENDIF

       IF (DIAGNOSTICS_IS_ON('KEm_dEg ',myThid)  ) THEN
         CALL MOM_INTERP_KE( bi,bj,k,2,tmpU,tmpV,tmpKE,myThid )
         CALL DIAGNOSTICS_FILL(tmpKE,'KEm_dEg ', k ,1, 2,bi,bj, myThid)
       ENDIF

       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('UUm_Diss',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_Diss',myThid) ) ) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpU(i,j) = 0.5 _d 0*(uvel0(i,j)+uVel(i,j,k,bi,bj))
     &          *u_dissh(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpU,'UUm_Diss',k,1,2,bi,bj,myThid)
       ENDIF
       
       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('VVm_Diss',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_Diss',myThid) ) ) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpV(i,j) = 0.5 _d 0*(vvel0(i,j)+vVel(i,j,k,bi,bj))
     &          *v_dissh(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpV,'VVm_Diss',k,1,2,bi,bj,myThid)
       ENDIF

       IF (DIAGNOSTICS_IS_ON('KEm_Diss',myThid)  ) THEN
         CALL MOM_INTERP_KE( bi,bj,k,2,tmpU,tmpV,tmpKE,myThid )
         CALL DIAGNOSTICS_FILL(tmpKE,'KEm_Diss', k ,1, 2,bi,bj, myThid)
       ENDIF

       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('UUm_Ext ',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_Ext ',myThid) )) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpU(i,j) = 0.5 _d 0*(uvel0(i,j)+uVel(i,j,k,bi,bj))
     &          *u_ext(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpU,'UUm_Ext ',k,1,2,bi,bj,myThid)
       ENDIF
       
       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('VVm_Ext ',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_Ext ',myThid) ) )THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpV(i,j) = 0.5 _d 0*(vvel0(i,j)+vVel(i,j,k,bi,bj))
     &          *v_ext(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpV,'VVm_Ext ',k,1,2,bi,bj,myThid)
       ENDIF

       IF (DIAGNOSTICS_IS_ON('KEm_Ext ',myThid)  ) THEN
         CALL MOM_INTERP_KE( bi,bj,k,2,tmpU,tmpV,tmpKE,myThid )
         CALL DIAGNOSTICS_FILL(tmpKE,'KEm_Ext ', k ,1, 2,bi,bj, myThid)
       ENDIF

       IF ( useDiagnostics .AND. 
     &    DIAGNOSTICS_IS_ON('UUm_Cori',myThid) ) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpU(i,j) = 0.5 _d 0*(uvel0(i,j)+uVel(i,j,k,bi,bj))
     &          *u_cori(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpU,'UUm_Cori',k,1,2,bi,bj,myThid)
       ENDIF
       
       IF ( useDiagnostics .AND. 
     &    DIAGNOSTICS_IS_ON('VVm_Cori',myThid) ) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpV(i,j) = 0.5 _d 0*(vvel0(i,j)+vVel(i,j,k,bi,bj))
     &          *v_cori(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpV,'VVm_Cori',k,1,2,bi,bj,myThid)
       ENDIF

       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('UUm_Adve',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_Adve',myThid) )) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpU(i,j) = 0.5 _d 0*(uvel0(i,j)+uVel(i,j,k,bi,bj))
     &          *u_advec(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpU,'UUm_Adve',k,1,2,bi,bj,myThid)
       ENDIF
       
       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('VVm_Adve',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_Adve',myThid) )) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpV(i,j) = 0.5 _d 0*(vvel0(i,j)+vVel(i,j,k,bi,bj))
     &          *v_advec(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpV,'VVm_Adve',k,1,2,bi,bj,myThid)
       ENDIF

       IF (DIAGNOSTICS_IS_ON('KEm_Adve',myThid)  ) THEN
         CALL MOM_INTERP_KE( bi,bj,k,2,tmpU,tmpV,tmpKE,myThid )
         CALL DIAGNOSTICS_FILL(tmpKE,'KEm_Adve', k ,1, 2,bi,bj, myThid)
       ENDIF

       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('UUm_Disv',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_Disv',myThid) )) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpU(i,j) = 0.5 _d 0*(uvel0(i,j)+uVel(i,j,k,bi,bj))
     &          *u_dissv(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpU,'UUm_Disv', k,1, 2,bi,bj, myThid)
       ENDIF
       
       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('VVm_Disv',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_Disv',myThid) ) )THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpV(i,j) = 0.5 _d 0*(vvel0(i,j)+vVel(i,j,k,bi,bj))
     &          *v_dissv(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpV,'VVm_Disv', k,1, 2,bi,bj, myThid)
       ENDIF

       IF (DIAGNOSTICS_IS_ON('KEm_Disv',myThid)  ) THEN
         CALL MOM_INTERP_KE( bi,bj,k,2,tmpU,tmpV,tmpKE,myThid )
         CALL DIAGNOSTICS_FILL(tmpKE,'KEm_Disv', k ,1, 2,bi,bj, myThid)
       ENDIF

       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('UUm_dPdx',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_dPg ',myThid) ) ) THEN
         tmpFac = -1. _d 0
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpU(i,j) = 0.5 _d 0*(uvel0(i,j)+uVel(i,j,k,bi,bj))
     &          *tmpFac*u_dphdx(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL( tmpU,'UUm_dPdx',k, 1, 2, bi, bj, myThid)
       ENDIF
       
       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('VVm_dPdy',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEm_dPg ',myThid) )) THEN
         tmpFac = -1. _d 0
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpV(i,j) = 0.5 _d 0*(vvel0(i,j)+vVel(i,j,k,bi,bj))
     &          *tmpFac*v_dphdy(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL( tmpV,'VVm_dPdy',k, 1, 2, bi, bj, myThid)
       ENDIF

       IF (DIAGNOSTICS_IS_ON('KEm_dPg ',myThid)  ) THEN
         CALL MOM_INTERP_KE( bi,bj,k,2,tmpU,tmpV,tmpKE,myThid )
         CALL DIAGNOSTICS_FILL(tmpKE,'KEm_dPg ', k ,1, 2,bi,bj, myThid)
       ENDIF

       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('UAB_gU  ',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEAB_g  ',myThid) ) )THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpU(i,j) = 0.5 _d 0*(uvel0(i,j)+uVel(i,j,k,bi,bj))
     &          *u_ab(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpU,'UAB_gU  ',k,1,2,bi,bj,myThid)
       ENDIF
       
       IF ( useDiagnostics .AND. 
     &    (DIAGNOSTICS_IS_ON('VAB_gV  ',myThid) .OR.
     &    DIAGNOSTICS_IS_ON('KEAB_g  ',myThid) ) ) THEN
         DO j=jMin,jMax
           DO i=iMin,iMax
             tmpV(i,j) = 0.5 _d 0*(vvel0(i,j)+vVel(i,j,k,bi,bj))
     &          *v_ab(i,j,k,bi,bj)
           ENDDO
         ENDDO
         CALL DIAGNOSTICS_FILL(tmpV,'VAB_gV  ',k,1,2,bi,bj,myThid)
       ENDIF

       IF (DIAGNOSTICS_IS_ON('KEAB_g  ',myThid)  ) THEN
         CALL MOM_INTERP_KE( bi,bj,k,2,tmpU,tmpV,tmpKE,myThid )
         CALL DIAGNOSTICS_FILL(tmpKE,'KEAB_g  ', k ,1, 2,bi,bj, myThid)
       ENDIF


#endif /* ALLOW_DIAGNOSTICS */

C-    end of k loop
      ENDDO

      RETURN
      END
