#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP 0
C !ROUTINE: EXCH2_RECV_RS1

C !INTERFACE:
      SUBROUTINE EXCH2_RECV_RS1(
     I       thisTile, nN,
     I       e2BufrRecSize,
     I       iBufr,
     O       e2Bufr1_RS,
     I       commSetting, myThid )

C !DESCRIPTION:
C     Scalar field (1 component) Exchange:
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
C     e2BufrRecSize :: Number of elements in each entry of e2Bufr1_RS
C     iBufr         :: number of buffer elements to transfer
C     e2Bufr1_RS    :: Data transport buffer array. This array is used in one of
C                   :: two ways. For PUT communication the entry in the buffer
C                   :: associated with the source for this receive (determined
C                   :: from the opposing_send index) is read.
C                   :: For MSG communication the entry in the buffer associated
C                   :: with this neighbor of this tile is used as a receive
C                   :: location for loading a linear stream of bytes.
C     commSetting   :: Mode of communication used to exchange with this neighbor
C     myThid        :: my Thread Id. number

      INTEGER thisTile, nN
      INTEGER e2BufrRecSize
      INTEGER iBufr
      _RS     e2Bufr1_RS( e2BufrRecSize )
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
      INTEGER theTag, theType
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
       theTag =  (soT-1)*W2_maxNeighbours + oNb
       tProc = W2_tileProc(thisTile)-1
       sProc = W2_tileProc(soT)-1
       theType = _MPI_TYPE_RS
       CALL MPI_Recv( e2Bufr1_RS, iBufr, theType, sProc,
     &                theTag, MPI_COMM_MODEL, mpiStatus, mpiRc )
#ifdef W2_E2_DEBUG_ON
       WRITE(msgBuf,'(A,I4,A,I4,A)')
     &   ' RECV FROM TILE=', soT, ' (proc = ',sProc,')'
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,I4,A,I4,A)')
     &   '  INTO TILE=', thisTile, ' (proc = ',tProc,')'
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,I10)') '            TAG=', theTag
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     I                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,'(A,I4)')  '            NEL=', iBufr
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
