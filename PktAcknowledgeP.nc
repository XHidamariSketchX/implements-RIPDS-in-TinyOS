/**
 *	interface of send IPv6 packet
 *	@author xuji
 *	@date   2013/7/7
 */
#include <message.h>
#include <AM.h>
#include "NetworkCoding.h"


module PktAcknowledgeP {
  uses interface AMSend;
  uses interface AMPacket;
  uses interface Packet;
  uses interface Receive;
  uses interface SplitControl as AMControl;
  provides interface ACK;
  provides interface SplitControl as ACKControl;
}
implementation {
  bool busy = FALSE;
  message_t ACKmsg;
  am_addr_t myAddr;
  AckPacket_t* ack;
  command error_t ACKControl.start() {
    call AMControl.start();
    return SUCCESS;
  }
  command error_t ACKControl.stop(){
	  call AMControl.stop();
    return SUCCESS;
  }
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      signal ACKControl.startDone(err);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  	signal ACKControl.stopDone(err);
  }

/*************************�����յ���ACK***********************************************/
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    //ȷ���յ�ACK��
    if (len == sizeof(AckPacket_t)) {
    	//����ȷ��
      //֪ͨ�ϲ㵥���ڵ��Ѿ��������Ϊenc_sn group g ��m�������
      signal ACK.PacketHasBeenAcked(((AckPacket_t*)payload)->enc_sn,((AckPacket_t*)payload)->g);
    }
    return msg;
  }
event void AMSend.sendDone(message_t* msg, error_t err) {

		
		busy = FALSE;
	}
/***************************����ACK***********************************/
  command void ACK.sendACKtoSender(uint8_t enc_sn,uint8_t g) {
    myAddr=call AMPacket.address();
		ack=(AckPacket_t*)(call Packet.getPayload(&ACKmsg, sizeof(AckPacket_t)));
		//��־���͸���һ���ڵ�ȷ��
		ack->enc_sn=enc_sn;
		ack->g=g;
		while(busy);
			busy=TRUE;
			if (call AMSend.send(myAddr-1,&ACKmsg, sizeof(AckPacket_t)) == SUCCESS) {
    		}
	} 
	

}
