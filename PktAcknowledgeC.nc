/**
 *	
 *	@author xuji
 *	@date   2013/7/8
 */

#include "NetworkCoding.h"
#include "message.h"

#ifdef ENABLE_PRINTF_DEBUG
#include "printf.h"
#endif /* ENABLE_PRINTF_DEBUG */

configuration PktAcknowledgeC {
    provides {
			interface ACK;
			interface SplitControl as ACKControl;
    }
}
implementation { 
		components PktAcknowledgeP;
	  components new AMSenderC(AM_ID_ACK) as acams;
		components new AMReceiverC(AM_ID_ACK) as acsmr;
		components ActiveMessageC as AM;
		ACK=PktAcknowledgeP.ACK;
		ACKControl=PktAcknowledgeP.ACKControl;
		
	  PktAcknowledgeP.Receive ->acsmr.Receive;
    PktAcknowledgeP.AMSend ->acams.AMSend;
 		PktAcknowledgeP.AMPacket ->AM;
 		PktAcknowledgeP.Packet ->AM;
 		PktAcknowledgeP.AMControl ->AM;
}
