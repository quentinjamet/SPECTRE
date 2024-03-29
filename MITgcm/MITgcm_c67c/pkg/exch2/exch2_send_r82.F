#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP 0
C !ROUTINE: EXCH2_SEND_R82

C !INTERFACE:
      SUBROUTINE EXCH2_SEND_R82 (
     I       thisTile, nN,
     I       e2BufrRecSize,
     I       iBufr1, iBufr2,
     I       e2Bufr1_R8, e2Bufr2_R8,
     O       e2_msgHandle,
     I       commSetting, myThid )

C !DESCRIPTION:
C     Two components vector field Exchange:
C     Send buffer to the target Process.
C     Buffer has been previously filled with interior data point
C     corresponding to the target-neighbour-edge overlap region.

C !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"

C !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     thisTile      :: sending tile Id. number
C     nN            :: Neighbour entry that we are processing
C     e2BufrRecSize :: Number of elements in each entry of e2Bufr1_R8
C     iBufr1        :: number of buffer-1 elements to transfer
C     iBufr2        :: number of buffer-2 elements to transfer
C     e2Bufr1_R8    :: Data transport buffer array. This array is used in one of
C     e2Bufr2_R8    :: two ways. For PUT communication the entry in the buffer
C                   :: associated with the source for this receive (determined
C                   :: from the opposing_send index) is read.
C                   :: For MSG communication the entry in the buffer associated
C                   :: with this neighbor of this tile is used as a receive
C                   :: location for loading a linear stream of bytes.
C     e2_msgHandles :: Synchronization and coordination data structure used to
C                   :: coordinate access to e2Bufr1_R8 or to regulate message
C                   :: buffering. In PUT communication sender will increment
C                   :: handle entry once data is ready in buffer. Receiver will
C                   :: decrement handle once data is consumed from buffer.
C                   :: For MPI MSG communication MPI_Wait uses handle to check
C                   :: Isend has cleared. This is done in routine after receives.
C     commSetting   :: Mode of communication used to exchange with this neighbor
C     myThid        :: my Thread Id. number

      INTEGER thisTile, nN
      INTEGER e2BufrRecSize
      INTEGER iBufr1, iBufr2
      _R8     e2Bufr1_R8( e2BufrRecSize )
      _R8     e2Bufr2_R8( e2BufrRecSize )
      INTEGER e2_msgHandle(2)
      CHARACTER commSetting
      INTEGER myThid
CEOP

#ifdef ALLOW_USE_MPI
C !LOCAL VARIABLES:
C     == Local variables ==
C     tgT         :: Target tile
      INTEGER  tgT

C     MPI setup
      INTEGER theTag1, theTag2, theType, theHandle1, theHandle2
      INTEGER sProc, tProc, mpiRc
#ifdef W2_E2_DEBUG_ON
      CHARACTER*(MAX_LEN_MBUF) msgBuf
#endif

      tgT = exch2_neighbourId(nN, thisTile )

C     Do data transport depending on communication mechanism between
C     source and target tile
      IF ( commSetting .EQ. 'M' ) THEN
C      Setup MPI stuff here
       theTag1 =  (thisTile-1)*W2_maxNeighbours*2 + nN-1
       theTag2 =  (thisTile-1)*W2_maxNeighbours*2
     &         + W2_maxNeighbours + nN-1
       tProc = W2_tileProc(tgT)-1
       sProc = W2_tileProc(thisTile)-1
       theType = _MPI_TYPE_R8
#ifdef W2_E2_DEBUG_ON
       WRITE(msgBuf,'(A,I5,A,I5,A)')
     &  ' SEND FROM TILE=', thisTile, ' (proc =',sProc,')'
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid)
       WRITE(msgBuf,'(A,I5,A,I5,A)')
     &  '        TO TILE=', tgT ' (proc =',tProc,')'
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid)
       WRITE(msgBuf,'(A,I10)') '            TAG1=', theTag1
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid)
       WRITE(msgBuf,'(A,I4)')  '            NEL1=', iBufr1
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid)
       WRITE(msgBuf,'(A,I10)') '            TAG2=', theTag2
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid)
       WRITE(msgBuf,'(A,I4)')  '            NEL2=', iBufr2
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid)
#endif /* W2_E2_DEBUG_ON */
       CALL MPI_Isend( e2Bufr1_R8, iBufr1, theType,
     I                 tProc, theTag1, MPI_COMM_MODEL,
     O                 theHandle1, mpiRc )
       CALL MPI_Isend( e2Bufr2_R8, iBufr2, theType,
     I                 tProc, theTag2, MPI_COMM_MODEL,
     O                 theHandle2, mpiRc )
C      Store MPI_Wait token in messageHandle.
       e2_msgHandle(1) = theHandle1
       e2_msgHandle(2) = theHandle2
      ENDIF
#endif /* ALLOW_USE_MPI */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
