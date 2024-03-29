#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP 0
C !ROUTINE: EXCH2_PUT_RS2

C !INTERFACE:
      SUBROUTINE EXCH2_PUT_RS2 (
     I       tIlo1, tIhi1, tIlo2, tIhi2, tiStride,
     I       tJlo1, tJhi1, tJlo2, tJhi2, tjStride,
     I       tKlo, tKhi, tkStride,
     I       oIs1, oJs1, oIs2, oJs2,
     I       thisTile, nN,
     I       e2BufrRecSize,
     O       iBufr1, iBufr2,
     O       e2Bufr1_RS, e2Bufr2_RS,
     I       array1,
     I       array2,
     I       i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     I       i2Lo, i2Hi, j2Lo, j2Hi, k2Lo, k2Hi,
     O       e2_msgHandle,
     I       commSetting, withSigns, myThid )

C !DESCRIPTION:
C     Two components vector field Exchange:
C     Put into buffer exchanged data from this source tile.
C     Those data are intended to fill-in the
C     target-neighbour-edge overlap region.

C !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"
#ifdef W2_E2_DEBUG_ON
# include "W2_EXCH2_PARAMS.h"
#endif

C !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     tIlo1, tIhi1  :: index range in I that will be filled in target "array1"
C     tIlo2, tIhi2  :: index range in I that will be filled in target "array2"
C     tIstride      :: index step  in I that will be filled in target arrays
C     tJlo1, tJhi1  :: index range in J that will be filled in target "array1"
C     tJlo2, tJhi2  :: index range in J that will be filled in target "array2"
C     tJstride      :: index step  in J that will be filled in target arrays
C     tKlo, tKhi    :: index range in K that will be filled in target arrays
C     tKstride      :: index step  in K that will be filled in target arrays
C     oIs1, oJs1    :: I,J index offset in target to source-1 connection
C     oIs2, oJs2    :: I,J index offset in target to source-2 connection
C     thisTile      :: sending tile Id. number
C     nN            :: Neighbour entry that we are processing
C     e2BufrRecSize :: Number of elements in each entry of e2Bufr[1,2]_RS
C     iBufr1        :: number of buffer-1 elements filled in
C     iBufr2        :: number of buffer-2 elements filled in
C     e2Bufr1_RS    :: Data transport buffer array. This array is used in one of
C     e2Bufr2_RS    :: two ways. For PUT communication the entry in the buffer
C                   :: associated with the source for this receive (determined
C                   :: from the opposing_send index) is read.
C                   :: For MSG communication the entry in the buffer associated
C                   :: with this neighbor of this tile is used as a receive
C                   :: location for loading a linear stream of bytes.
C     array1        :: 1rst Component target array that this receive writes to.
C     array2        :: 2nd  Component target array that this receive writes to.
C     i1Lo, i1Hi    :: I coordinate bounds of target array1
C     j1Lo, j1Hi    :: J coordinate bounds of target array1
C     k1Lo, k1Hi    :: K coordinate bounds of target array1
C     i2Lo, i2Hi    :: I coordinate bounds of target array2
C     j2Lo, j2Hi    :: J coordinate bounds of target array2
C     k2Lo, k2Hi    :: K coordinate bounds of target array2
C     e2_msgHandles :: Synchronization and coordination data structure used to
C                   :: coordinate access to e2Bufr1_RS or to regulate message
C                   :: buffering. In PUT communication sender will increment
C                   :: handle entry once data is ready in buffer. Receiver will
C                   :: decrement handle once data is consumed from buffer.
C                   :: For MPI MSG communication MPI_Wait uses handle to check
C                   :: Isend has cleared. This is done in routine after receives.
C     commSetting   :: Mode of communication used to exchange with this neighbor
C     withSigns     :: Flag controlling whether vector field is signed.
C     myThid        :: my Thread Id. number

      INTEGER tIlo1, tIhi1, tIlo2, tIhi2, tiStride
      INTEGER tJlo1, tJhi1, tJlo2, tJhi2, tjStride
      INTEGER tKlo, tKhi, tkStride
      INTEGER oIs1, oJs1, oIs2, oJs2
      INTEGER thisTile, nN
      INTEGER e2BufrRecSize
      INTEGER iBufr1, iBufr2
      _RS     e2Bufr1_RS( e2BufrRecSize )
      _RS     e2Bufr2_RS( e2BufrRecSize )
      INTEGER i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi
      INTEGER i2Lo, i2Hi, j2Lo, j2Hi, k2Lo, k2Hi
      _RS     array1(i1Lo:i1Hi,j1Lo:j1Hi,k1Lo:k1Hi)
      _RS     array2(i2Lo:i2Hi,j2Lo:j2Hi,k2Lo:k2Hi)
      INTEGER e2_msgHandle(2)
      CHARACTER commSetting
      LOGICAL withSigns
      INTEGER myThid
CEOP

C !LOCAL VARIABLES:
C     == Local variables ==
C     itl,jtl,ktl :: Loop counters
C                 :: itl etc... target local
C                 :: itc etc... target canonical
C                 :: isl etc... source local
C                 :: isc etc... source canonical
C     tgT         :: Target tile
C     itb, jtb    :: Target local to canonical offsets
      INTEGER itl, jtl, ktl
      INTEGER itc, jtc
      INTEGER isc, jsc
      INTEGER isl, jsl
      INTEGER tgT
      INTEGER itb, jtb
      INTEGER isb, jsb
      INTEGER pi(2), pj(2)
      INTEGER iLoc
      _RS     sa1, sa2, val1, val2

      CHARACTER*(MAX_LEN_MBUF) msgBuf
#ifdef W2_E2_DEBUG_ON
      LOGICAL prtFlag
#endif

      IF     ( commSetting .EQ. 'P' ) THEN
C      Need to check that buffer synchronisation token is decremented
C      before filling buffer. This is needed for parallel processing
C      shared memory modes only.
      ENDIF

      tgT = exch2_neighbourId(nN, thisTile )
      itb = exch2_tBasex(tgT)
      jtb = exch2_tBasey(tgT)
      isb = exch2_tBasex(thisTile)
      jsb = exch2_tBasey(thisTile)
      pi(1)=exch2_pij(1,nN,thisTile)
      pi(2)=exch2_pij(2,nN,thisTile)
      pj(1)=exch2_pij(3,nN,thisTile)
      pj(2)=exch2_pij(4,nN,thisTile)

C     Extract into bufr1 (target i-index array)
C     if pi(1) is  1 then +i in target <=> +i in source so bufr1 should get +array1
C     if pi(1) is -1 then +i in target <=> -i in source so bufr1 should get -array1
C     if pj(1) is  1 then +i in target <=> +j in source so bufr1 should get +array2
C     if pj(1) is -1 then +i in target <=> -j in source so bufr1 should get -array2
      sa1 = pi(1)
      sa2 = pj(1)
      IF ( .NOT. withSigns ) THEN
       sa1 = ABS(sa1)
       sa2 = ABS(sa2)
      ENDIF
C     if pi(1) is 1 then +i in source aligns with +i in target
C     if pj(1) is 1 then +i in source aligns with +j in target
#ifdef W2_E2_DEBUG_ON
      IF ( ABS(W2_printMsg).GE.2 ) THEN
        WRITE(msgBuf,'(2A,I5,I3,A,I5)') 'EXCH2_PUT_RS2',
     &    ' sourceTile,neighb=', thisTile, nN, ' : targetTile=', tgT
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                      SQUEEZE_BOTH, myThid )
      ENDIF
      prtFlag = ABS(W2_printMsg).GE.3
#endif /* W2_E2_DEBUG_ON */
      iBufr1=0
      DO ktl=tKlo,tKhi,tkStride
       DO jtl=tJlo1, tJhi1, tjStride
        DO itl=tIlo1, tIhi1, tiStride
         iBufr1=iBufr1+1
         itc = itl+itb
         jtc = jtl+jtb
         isc = pi(1)*itc+pi(2)*jtc+oIs1
         jsc = pj(1)*itc+pj(2)*jtc+oJs1
         isl = isc-isb
         jsl = jsc-jsb
#ifdef W2_E2_DEBUG_ON
         IF ( prtFlag ) THEN
          WRITE(msgBuf,'(A,2I5)')
     &          'EXCH2_PUT_RS2 target  u(itl,jtl) =', itl, jtl
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                        SQUEEZE_RIGHT, myThid )
          IF (     pi(1) .EQ. 1 ) THEN
C        i index aligns
           WRITE(msgBuf,'(A,2I5)')
     &          '              source +u(isl,jsl) =', isl, jsl
          ELSEIF ( pi(1) .EQ. -1 ) THEN
C        reversed i index aligns
           WRITE(msgBuf,'(A,2I5)')
     &          '              source -u(isl,jsl) =', isl, jsl
          ELSEIF ( pj(1) .EQ.  1 ) THEN
           WRITE(msgBuf,'(A,2I5)')
     &          '              source +v(isl,jsl) =', isl, jsl
          ELSEIF ( pj(1) .EQ. -1 ) THEN
           WRITE(msgBuf,'(A,2I5)')
     &          '              source -v(isl,jsl) =', isl, jsl
          ENDIF
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                        SQUEEZE_RIGHT, myThid )
         ENDIF
         IF ( isl .LT. i1Lo .OR. isl .GT. i1Hi ) THEN
C         Forward mode send getting from points outside of the
C         tiles exclusive domain bounds in X. This should not happen
          WRITE(msgBuf,'(2A,I4,A,2I4,A)') 'EXCH2_PUT_RS2:',
     &      ' isl=', isl, ' is out of bounds (i1Lo,Hi=',i1Lo,i1Hi,')'
          CALL PRINT_ERROR ( msgBuf, myThid )
          WRITE(msgBuf,'(2A,2I4,A,3I6)') 'EXCH2_PUT_RS2:',
     &     ' for itl,jtl=', itl, jtl, ' itc,jtc,isc=', itc, jtc, isc
          CALL PRINT_ERROR ( msgBuf, myThid )
          STOP 'ABNORMAL END: S/R EXCH2_PUT_RS2 (isl out of bounds)'
         ENDIF
         IF ( jsl .LT. j1Lo .OR. jsl .GT. j1Hi ) THEN
C         Forward mode send getting from points outside of the
C         tiles exclusive domain bounds in Y. This should not happen
          WRITE(msgBuf,'(2A,I4,A,2I4,A)') 'EXCH2_PUT_RS2:',
     &      ' jsl=', jsl, ' is out of bounds (j1Lo,Hi=',j1Lo,j1Hi,')'
          CALL PRINT_ERROR ( msgBuf, myThid )
          WRITE(msgBuf,'(2A,2I4,A,3I6)') 'EXCH2_PUT_RS2:',
     &     ' for itl,jtl=', itl, jtl, ' itc,jtc,jsc=', itc, jtc, jsc
          CALL PRINT_ERROR ( msgBuf, myThid )
          STOP 'ABNORMAL END: S/R EXCH2_PUT_RS2 (jsl out of bounds)'
         ENDIF
#endif /* W2_E2_DEBUG_ON */
#ifdef W2_USE_E2_SAFEMODE
         iLoc = MIN( iBufr1, e2BufrRecSize )
#else
         iLoc = iBufr1
#endif
         val1 = sa1*array1(isl,jsl,ktl)
     &        + sa2*array2(isl,jsl,ktl)
         e2Bufr1_RS(iLoc) = val1
        ENDDO
       ENDDO
      ENDDO
      IF ( iBufr1 .GT. e2BufrRecSize ) THEN
C     Ran off end of buffer. This should not happen
        WRITE(msgBuf,'(2A,I9,A,I9)') 'EXCH2_PUT_RS2:',
     &   ' iBufr1=', iBufr1, ' exceeds E2BUFR size=', e2BufrRecSize
        CALL PRINT_ERROR ( msgBuf, myThid )
        STOP 'ABNORMAL END: S/R EXCH2_PUT_RS2 (iBufr1 over limit)'
      ENDIF

C     Extract values into bufr2
C     if pi(2) is  1 then +j in target <=> +i in source so bufr1 should get +array1
C     if pi(2) is -1 then +j in target <=> -i in source so bufr1 should get -array1
C     if pj(2) is  1 then +j in target <=> +j in source so bufr1 should get +array2
C     if pj(2) is -1 then +j in target <=> -j in source so bufr1 should get -array2
      sa1 = pi(2)
      sa2 = pj(2)
      IF ( .NOT. withSigns ) THEN
       sa1 = ABS(sa1)
       sa2 = ABS(sa2)
      ENDIF
      iBufr2=0
      DO ktl=tKlo,tKhi,tkStride
       DO jtl=tJlo2, tJhi2, tjStride
        DO itl=tIlo2, tIhi2, tiStride
         iBufr2=iBufr2+1
         itc = itl+itb
         jtc = jtl+jtb
         isc = pi(1)*itc+pi(2)*jtc+oIs2
         jsc = pj(1)*itc+pj(2)*jtc+oJs2
         isl = isc-isb
         jsl = jsc-jsb
#ifdef W2_E2_DEBUG_ON
         IF ( prtFlag ) THEN
          WRITE(msgBuf,'(A,2I5)')
     &          'EXCH2_PUT_RS2 target  v(itl,jtl) =', itl, jtl
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                        SQUEEZE_RIGHT, myThid )
          IF (     pi(2) .EQ. 1 ) THEN
C        i index aligns
           WRITE(msgBuf,'(A,2I5)')
     &          '              source +u(isl,jsl) =', isl, jsl
          ELSEIF ( pi(2) .EQ. -1 ) THEN
C        reversed i index aligns
           WRITE(msgBuf,'(A,2I5)')
     &          '              source -u(isl,jsl) =', isl, jsl
          ELSEIF ( pj(2) .EQ.  1 ) THEN
           WRITE(msgBuf,'(A,2I5)')
     &          '              source +v(isl,jsl) =', isl, jsl
          ELSEIF ( pj(2) .EQ. -1 ) THEN
           WRITE(msgBuf,'(A,2I5)')
     &          '              source -v(isl,jsl) =', isl, jsl
          ENDIF
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                        SQUEEZE_RIGHT, myThid )
         ENDIF
         IF ( isl .LT. i2Lo .OR. isl .GT. i2Hi ) THEN
C         Forward mode send getting from points outside of the
C         tiles exclusive domain bounds in X. This should not happen
          WRITE(msgBuf,'(2A,I4,A,2I4,A)') 'EXCH2_PUT_RS2:',
     &      ' isl=', isl, ' is out of bounds (i2Lo,Hi=',i2Lo,i2Hi,')'
          CALL PRINT_ERROR ( msgBuf, myThid )
          WRITE(msgBuf,'(2A,2I4,A,3I6)') 'EXCH2_PUT_RS2:',
     &     ' for itl,jtl=', itl, jtl, ' itc,jtc,isc=', itc, jtc, isc
          CALL PRINT_ERROR ( msgBuf, myThid )
          STOP 'ABNORMAL END: S/R EXCH2_PUT_RS2 (isl out of bounds)'
         ENDIF
         IF ( jsl .LT. j2Lo .OR. jsl .GT. j2Hi ) THEN
C         Forward mode send getting from points outside of the
C         tiles exclusive domain bounds in Y. This should not happen
          WRITE(msgBuf,'(2A,I4,A,2I4,A)') 'EXCH2_PUT_RS2:',
     &      ' jsl=', jsl, ' is out of bounds (j2Lo,Hi=',j2Lo,j2Hi,')'
          CALL PRINT_ERROR ( msgBuf, myThid )
          WRITE(msgBuf,'(2A,2I4,A,3I6)') 'EXCH2_PUT_RS2:',
     &     ' for itl,jtl=', itl, jtl, ' itc,jtc,jsc=', itc, jtc, jsc
          CALL PRINT_ERROR ( msgBuf, myThid )
          STOP 'ABNORMAL END: S/R EXCH2_PUT_RS2 (jsl out of bounds)'
         ENDIF
#endif /* W2_E2_DEBUG_ON */
#ifdef W2_USE_E2_SAFEMODE
         iLoc = MIN( iBufr2, e2BufrRecSize )
#else
         iLoc = iBufr2
#endif
         val2 = sa1*array1(isl,jsl,ktl)
     &        + sa2*array2(isl,jsl,ktl)
         e2Bufr2_RS(iLoc) = val2
        ENDDO
       ENDDO
      ENDDO
      IF ( iBufr2 .GT. e2BufrRecSize ) THEN
C     Ran off end of buffer. This should not happen
        WRITE(msgBuf,'(2A,I9,A,I9)') 'EXCH2_PUT_RS2:',
     &   ' iBufr2=', iBufr2, ' exceeds E2BUFR size=', e2BufrRecSize
        CALL PRINT_ERROR ( msgBuf, myThid )
        STOP 'ABNORMAL END: S/R EXCH2_PUT_RS2 (iBufr2 over limit)'
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
