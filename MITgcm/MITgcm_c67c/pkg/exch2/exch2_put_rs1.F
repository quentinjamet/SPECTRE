#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP 0
C !ROUTINE: EXCH2_PUT_RS1

C !INTERFACE:
      SUBROUTINE EXCH2_PUT_RS1 (
     I       tIlo, tIhi, tiStride,
     I       tJlo, tJhi, tjStride,
     I       tKlo, tKhi, tkStride,
     I       thisTile, nN,
     I       e2BufrRecSize,
     O       iBufr,
     O       e2Bufr1_RS,
     I       array,
     I       i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     O       e2_msgHandle,
     I       commSetting, myThid )

C !DESCRIPTION:
C     Scalar field (1 component) Exchange:
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
C     tIlo, tIhi    :: index range in I that will be filled in target "array"
C     tIstride      :: index step  in I that will be filled in target "array"
C     tJlo, tJhi    :: index range in J that will be filled in target "array"
C     tJstride      :: index step  in J that will be filled in target "array"
C     tKlo, tKhi    :: index range in K that will be filled in target "array"
C     tKstride      :: index step  in K that will be filled in target "array"
C     thisTile      :: sending tile Id. number
C     nN            :: Neighbour entry that we are processing
C     e2BufrRecSize :: Number of elements in each entry of e2Bufr1_RS
C     iBufr         :: number of buffer elements filled in
C     e2Bufr1_RS    :: Data transport buffer array. This array is used in one of
C                   :: two ways. For PUT communication the entry in the buffer
C                   :: associated with the source for this receive (determined
C                   :: from the opposing_send index) is read.
C                   :: For MSG communication the entry in the buffer associated
C                   :: with this neighbor of this tile is used as a receive
C                   :: location for loading a linear stream of bytes.
C     array         :: Source array where the data come from
C     i1Lo, i1Hi    :: I coordinate bounds of target array
C     j1Lo, j1Hi    :: J coordinate bounds of target array
C     k1Lo, k1Hi    :: K coordinate bounds of target array
C     e2_msgHandles :: Synchronization and coordination data structure used to
C                   :: coordinate access to e2Bufr1_RS or to regulate message
C                   :: buffering. In PUT communication sender will increment
C                   :: handle entry once data is ready in buffer. Receiver will
C                   :: decrement handle once data is consumed from buffer.
C                   :: For MPI MSG communication MPI_Wait uses handle to check
C                   :: Isend has cleared. This is done in routine after receives.
C     commSetting   :: Mode of communication used to exchange with this neighbor
C     myThid        :: my Thread Id. number

      INTEGER tILo, tIHi, tiStride
      INTEGER tJLo, tJHi, tjStride
      INTEGER tKLo, tKHi, tkStride
      INTEGER i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi
      INTEGER thisTile, nN
      INTEGER e2BufrRecSize
      INTEGER iBufr
      _RS     e2Bufr1_RS( e2BufrRecSize )
      _RS     array(i1Lo:i1Hi,j1Lo:j1Hi,k1Lo:k1Hi)
      INTEGER e2_msgHandle(1)
      INTEGER myThid
      CHARACTER commSetting
CEOP

C !LOCAL VARIABLES:
C     == Local variables ==
C     itl,jtl,ktl :: Loop counters
C                 :: itl etc... target local
C                 :: itc etc... target canonical
C                 :: isl etc... source local
C                 :: isc etc... source canonical
C     tgT         :: Target tile Id. number
C     itb, jtb    :: Target local to canonical offsets
      INTEGER itl, jtl, ktl
      INTEGER itc, jtc
      INTEGER isc, jsc
      INTEGER isl, jsl
      INTEGER tgT
      INTEGER itb, jtb
      INTEGER isb, jsb
      INTEGER pi(2), pj(2), oi, oj
      INTEGER iLoc

      CHARACTER*(MAX_LEN_MBUF) msgBuf
#ifdef W2_E2_DEBUG_ON
      LOGICAL prtFlag
#endif

c     IF     ( commSetting .EQ. 'P' ) THEN
C      Need to check that buffer synchronisation token is decremented
C      before filling buffer.
c     ENDIF

      tgT = exch2_neighbourId(nN, thisTile )
      itb = exch2_tBasex(tgT)
      jtb = exch2_tBasey(tgT)
      isb = exch2_tBasex(thisTile)
      jsb = exch2_tBasey(thisTile)
      pi(1)=exch2_pij(1,nN,thisTile)
      pi(2)=exch2_pij(2,nN,thisTile)
      pj(1)=exch2_pij(3,nN,thisTile)
      pj(2)=exch2_pij(4,nN,thisTile)
      oi  = exch2_oi(nN,thisTile)
      oj  = exch2_oj(nN,thisTile)
#ifdef W2_E2_DEBUG_ON
      IF ( ABS(W2_printMsg).GE.2 ) THEN
        WRITE(msgBuf,'(2A,I5,I3,A,I5)') 'EXCH2_PUT_RS1',
     &    ' sourceTile,neighb=', thisTile, nN, ' : targetTile=', tgT
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                      SQUEEZE_BOTH, myThid )
      ENDIF
      prtFlag = ABS(W2_printMsg).GE.3
#endif /* W2_E2_DEBUG_ON */
      iBufr=0
      DO ktl=tKlo,tKhi,tKStride
       DO jtl=tJLo, tJHi, tjStride
        DO itl=tILo, tIHi, tiStride
         iBufr=iBufr+1
         itc = itl+itb
         jtc = jtl+jtb
         isc = pi(1)*itc+pi(2)*jtc+oi
         jsc = pj(1)*itc+pj(2)*jtc+oj
         isl = isc-isb
         jsl = jsc-jsb
#ifdef W2_E2_DEBUG_ON
         IF ( prtFlag ) THEN
          WRITE(msgBuf,'(A,2I5)')
     &          'EXCH2_PUT_RS1 target  t(itl,jtl) =', itl, jtl
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                        SQUEEZE_RIGHT, myThid )
          WRITE(msgBuf,'(A,2I5)')
     &          '              source   (isl,jsl) =', isl, jsl
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                        SQUEEZE_RIGHT, myThid )
         ENDIF
         IF ( isl .LT. i1Lo .OR. isl .GT. i1Hi ) THEN
C         Forward mode send getting from points outside of the
C         tiles exclusive domain bounds in X. This should not happen
          WRITE(msgBuf,'(2A,I4,A,2I4,A)') 'EXCH2_PUT_RS1:',
     &      ' isl=', isl, ' is out of bounds (i1Lo,Hi=',i1Lo,i1Hi,')'
          CALL PRINT_ERROR ( msgBuf, myThid )
          WRITE(msgBuf,'(2A,2I4,A,3I6)') 'EXCH2_PUT_RS1:',
     &     ' for itl,jtl=', itl, jtl, ' itc,jtc,isc=', itc, jtc, isc
          CALL PRINT_ERROR ( msgBuf, myThid )
          STOP 'ABNORMAL END: S/R EXCH2_PUT_RS1 (isl out of bounds)'
         ENDIF
         IF ( jsl .LT. j1Lo .OR. jsl .GT. j1Hi ) THEN
C         Forward mode send getting from points outside of the
C         tiles exclusive domain bounds in Y. This should not happen
          WRITE(msgBuf,'(2A,I4,A,2I4,A)') 'EXCH2_PUT_RS1:',
     &      ' jsl=', jsl, ' is out of bounds (j1Lo,Hi=',j1Lo,j1Hi,')'
          CALL PRINT_ERROR ( msgBuf, myThid )
          WRITE(msgBuf,'(2A,2I4,A,3I6)') 'EXCH2_PUT_RS1:',
     &     ' for itl,jtl=', itl, jtl, ' itc,jtc,jsc=', itc, jtc, jsc
          CALL PRINT_ERROR ( msgBuf, myThid )
          STOP 'ABNORMAL END: S/R EXCH2_PUT_RS1 (jsl out of bounds)'
         ENDIF
#endif /* W2_E2_DEBUG_ON */
#ifdef W2_USE_E2_SAFEMODE
         iLoc = MIN( iBufr, e2BufrRecSize )
#else
         iLoc = iBufr
#endif
         e2Bufr1_RS(iLoc) = array(isl,jsl,ktl)
        ENDDO
       ENDDO
      ENDDO
      IF ( iBufr .GT. e2BufrRecSize ) THEN
C     Ran off end of buffer. This should not happen
        WRITE(msgBuf,'(2A,I9,A,I9)') 'EXCH2_PUT_RS1:',
     &   ' iBufr =', iBufr, ' exceeds E2BUFR size=', e2BufrRecSize
        CALL PRINT_ERROR ( msgBuf, myThid )
        STOP 'ABNORMAL END: S/R EXCH2_PUT_RS1 (iBufr over limit)'
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
