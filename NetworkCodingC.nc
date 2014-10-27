/**
 *	
 *	@author xuji
 *	@date   2013/7/7
 */

#include "NetworkCoding.h"
#include "message.h"


configuration NetworkCodingC {
    provides {
			interface NC;
			interface SplitControl as NCControl;
    }
}
implementation { 
    components NetworkCodingP;
    components VandermondeCodingC; 
    components new TimerMilliC() as Timer0;
    components new TimerMilliC() as Timer1;
	components new PoolC(vdm_data_t,20) as DataPoolC;
	components new PoolC(RxSegmentDecodingInf_t,8) as DecodingInfPoolC;
	components new QueueC(RxSegmentDecodingInf_t *,8) as DecodingInfQueueC;
    components PktAcknowledgeC;
    components ActiveMessageC as AM;
    components ActiveMessageAddressC;
    components new AMSenderC(AM_ID_IP_MSG) as ncSender;
	components new AMReceiverC(AM_ID_IP_MSG) as ncReceiver;
		
	components MainC;
    NC=NetworkCodingP.NC;
    NCControl=NetworkCodingP.NCControl;
    
    NetworkCodingP.vc ->VandermondeCodingC.vc;
    NetworkCodingP.WaitNextFragTimer ->Timer0;
    NetworkCodingP.nextSendDelay ->Timer1;
    NetworkCodingP.DecodingInfPool ->DecodingInfPoolC;
    NetworkCodingP.DecodingInfQueue -> DecodingInfQueueC;
    
	NetworkCodingP.ACK -> PktAcknowledgeC.ACK;
	NetworkCodingP.ACKControl -> PktAcknowledgeC.ACKControl;
 
    NetworkCodingP.ActiveMessageAddress ->ActiveMessageAddressC;
	NetworkCodingP.Receive -> ncReceiver.Receive;
    NetworkCodingP.AMSend -> ncSender.AMSend;
    NetworkCodingP.MessageControl -> AM;
    NetworkCodingP.Packet -> AM;
    NetworkCodingP.AMPacket -> AM;

	VandermondeCodingC.VdmDataPool->DataPoolC;
}

