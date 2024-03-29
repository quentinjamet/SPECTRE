#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP 0
C !ROUTINE: EXCH2_RECV_R42

C !INTERFACE:
      SUBROUTINE EXCH2_RECV_R42(
     I       thisTile, nN,
     I       e2BufrRecSize,
     I       iBufr1, iBufr2,
     I       e2Bufr1_R4, e2Bufr2_R4,
     I       commSetting, myThid )

C !DESCRIPTION:
C     Two components vector field Exchange:
C     Receive into buffer exchanged data from the source Process.
C     buffer data will be used to fill in the tile-edge overlap region.

C !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"

C !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     thisTile      :: receiving tile Id. number
C     nN            :: Neighbour entry that we are processing
C     e2BufrRecSize :: Number of elements in each entry of e2Bufr1_R4
C     iBufr1        :: number of buffer-1 elements to transfer
C     iBufr2        :: number of buffer-2 elements to transfer
C     e2Bufr1_R4    :: Data transport buffer array. This array is used in one of
C     e2Bufr2_R4    :: two ways. For PUT communication the entry in the buffer
C                   :: associated with the source for this receive (determined
C                   :: from the opposing_send index) is read.
C                   :: For MSG communication the entry in the buffer associated
C                   :: with this neighbor of this tile is used as a receive
C                   :: location for loading a linear stream of bytes.
C     commSetting   :: Mode of communication used to exchange with this neighbor
C     myThid        :: my Thread Id. number

      INTEGER thisTile, nN
      INTEGER e2BufrRecSize
      INTEGER iBufr1, iBufr2
      _R4     e2Bufr1_R4( e2BufrRecSize )
      _R4     e2Bufr2_R4( e2BufrRecSize )
      CHARACTER commSetting
      INTEGER myThid
CEOP

#ifdef ALLOW_USE_MPI
C !LOCAL VARIABLES:
C     == Local variables ==
C     soT     :: Source tile Id. number
C     oNb     :: Opposing send record number
      INTEGER soT
      INTEGER oNb

C     MPI setup
      INTEGER theTag1, theTag2, theType
      INTEGER sProc, tProc
      INTEGER mpiStatus(MPI_STATUS_SIZE), mpiRc
#ifdef W2_E2_DEBUG_ON
      CHARACTER*(MAX_LEN_MBUF) msgBuf
#endif

      soT = exch2_neighbourId(nN, thisTile )
      oNb = exch2_opposingSend(nN, thisTile )

C     Handle receive end data transport according to communication mechanism
C     between source and target tile
      IF ( commSetting .EQ. 'M' ) THEN
C      Setup MPI stuff here
       theTag1 = (soT-1)*W2_maxNeighbours*2 + oNb-1
       theTag2 = (soT-1)*W2_maxNeighbours*2 + W2_maxNeighbours + oNb-1
       tProc = W2_tileProc(thisTile)-1
       sProc = W2_tileProc(soT)-1
       theType = _MPI_TYPE_R4
       CALL MPI_Recv( e2Bufr1_R4, iBufr1, theType, sProc,
     &                theTag1, MPI_COMM_MODEL, mpiStatus, mpiRc )
       CALL MPI_Recv( e2Bufr2_R4, iBufr2, theType, sProc,
     &                theTag2, MPI_COMM_MODEL, mpiStatus, mpiRc )
#ifdef W2_E2_DEBUG_ON
       WRITE(msgBuf,'(A,I4,A,I4,A)')
     &   ' RECV FROM TILE=', soT, ' (proc = ',sProc,')'
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,I4,A,I4,A)')
     &   '  INTO TILE=', thisTile, ' (proc = ',tProc,')'
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,I10)') '            TAG1=', theTag1
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,I4)')  '            NEL1=', iBufr1
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,I10)') '            TAG2=', theTag2
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,I4)')  '            NEL2=', iBufr2
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
#endif /* W2_E2_DEBUG_ON */
      ENDIF
#endif /* ALLOW_USE_MPI */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
