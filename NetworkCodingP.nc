/**
 *	
 *	@author xuji
 *	@date   2013/7/8
 */
#include "NetworkCoding.h"
#include "message.h"
#include <AM.h>

#include "printf.h"


module NetworkCodingP {
  provides {
		interface SplitControl as NCControl;
		interface NC;
  }
  uses {
  	interface SplitControl as MessageControl;
  	interface SplitControl as ACKControl;
  	interface Pool<RxSegmentDecodingInf_t> as DecodingInfPool;
  	interface Queue<RxSegmentDecodingInf_t *> as DecodingInfQueue;
  	interface VandermondeCoding as vc;
	  interface ACK;
	  interface Timer<TMilli> as WaitNextFragTimer;
	  interface Timer<TMilli> as nextSendDelay;
//		interface Pool<NC_Packet_t> as NCPool;
		interface Receive;
		interface AMSend;
		interface Packet;
		interface AMPacket;
		interface ActiveMessageAddress;
  }
}
implementation {
	//tx variables
	NCSendInf_t tx_pkt_inf;
	EncodingHdr_t * tx_enc_hdr;
	uint8_t last_frag_pending[CODING_LENGTH];
	vdm_coding_frag_t * g_encoded_frg_p;
	uint8_t g_tx_i;
	message_t g_msg;
	uint8_t * g_tx_payload;
	
	//rx variables
	NCSendInf_t rx_pkt_inf;
	EncodingHdr_t * rx_enc_hdr;
	uint8_t rx_data[maxNC_LEN];
	uint8_t rx_segment_map;//bit map for each group , 1 group lost;0 group received
	uint8_t rx_segment_map_patten;
	uint8_t * rx_cursor;
	uint8_t rx_i;
	//dec variables
	RxSegmentDecodingInf_t *decoding_inf=NULL;
	RxSegmentDecodingInf_t *decoding_inf_tmp;
	vdm_coding_frag_t decFrags[MAX_SEGMENT_LENGTH];
	vdm_data_t *dec_decodedData_p;
	bool rx_decoding_task_pedding=FALSE;
	uint8_t dec_i;
	//share variables 
	uint8_t g_enc_sn=0;
	bool pending=FALSE;
    bool WaitNextFragTimerFired=FALSE;
	//********debug
	uint8_t debug_r;
	uint16_t debug_addr=0xffff;
	inline void setZero(void *dst,uint16_t len){
		memset(dst, 0, len);
	}
	void NCSendInf_Pkt_clear(NCSendInf_t *pkt)
	{
    memset(pkt, 0, sizeof(*pkt));
	}

	void init(){
		NCSendInf_Pkt_clear(&tx_pkt_inf);
		NCSendInf_Pkt_clear(&rx_pkt_inf);
		call ActiveMessageAddress.setAddress(call ActiveMessageAddress.amGroup(), TOS_NODE_ID) ; 
	}
uint8_t next_enc_sn()
{
	
	if(g_enc_sn == 0xFF)
		g_enc_sn=1;
	else
		g_enc_sn++;
	return g_enc_sn;

}
void * my_memcpy(void *dst0, const void *src0, size_t len) 
{ 
	char *dst = (char *)dst0; 
	const char *src = (const char *)src0; 
	void *ret = dst0; 
	for (; len > 0; len--) 
		*dst++ = *src++; 
	return ret; 
}

uint8_t div_16_and_ceil(uint16_t numerator,uint8_t denominator){
	uint8_t tep=numerator % denominator;
	if(tep==0){
		return (uint8_t)(numerator/denominator);
	}else{
		numerator-=tep;
		return (uint8_t)(numerator/denominator+1);
	}
}
uint8_t div_1_f_and_ceil(uint8_t denominator){
	uint8_t tep=100%denominator;
	uint8_t had=100;
	if(tep==0){
		return 1;
	}else{
		had-=tep;
		return ((uint8_t)(had/denominator))+1;
	}
	
}
bool next_group(NCSendInf_t *pkt_inf ){
    //all fragments had been sent to next hop
	if(pkt_inf->remain_frag_num==0)
    {
        return FALSE;
    }
    //new segment acknoledgement flag set to FALSE
	pkt_inf->isACKed=FALSE;
	//remain fragments can fix one segment
	if((pkt_inf->remain_frag_num)>MAX_SEGMENT_LENGTH){
	    pkt_inf->current_m=MAX_SEGMENT_LENGTH;
		pkt_inf->current_M=MAX_SEGMENT_LENGTH*div_1_f_and_ceil(P);
		for(g_tx_i=0;g_tx_i<MAX_SEGMENT_LENGTH;g_tx_i++){
			pkt_inf->current_data[g_tx_i]=pkt_inf->cursor;
			pkt_inf->cursor+=CODING_LENGTH;
		}
		pkt_inf->remain_frag_num-=MAX_SEGMENT_LENGTH;
	
	}// final segment&remain fragments little than or = one segment
	else{
	
	    //last segment flag in most important bit in one Byte
        pkt_inf->current_s|=1<<7;
        //remain ONE fragment do not need encoding
        /*NOTE in following version this would be avoid by changing segment length  4,1 change to 3,2 or 2,3 */
        if(pkt_inf->remain_frag_num==1){
            pkt_inf->current_m=pkt_inf->remain_frag_num;
            if(pkt_inf->lastFragAlign==0){
                pkt_inf->lastFragAlign=CODING_LENGTH;
            }
            pkt_inf->remain_frag_num--;
        }//remain fragments need to encode
        else{
			pkt_inf->current_m=pkt_inf->remain_frag_num;
			pkt_inf->current_M=pkt_inf->remain_frag_num*div_1_f_and_ceil(P);	
			//NOTE WHY remain_frag_num-1: last fragment may not fix a <def>CODING_LENGTH</def> handle it out of for loop
			for(g_tx_i=0;pkt_inf->remain_frag_num-1;pkt_inf->remain_frag_num--,g_tx_i++){
		        pkt_inf->current_data[g_tx_i]=pkt_inf->cursor;
				pkt_inf->cursor+=CODING_LENGTH;
			}
			//last frag pending
			if(pkt_inf->lastFragAlign!=0){
			    setZero(last_frag_pending,CODING_LENGTH);
			    printf("debug:lastFragAlign=%u\n",pkt_inf->lastFragAlign);
			    printfflush();
                my_memcpy(last_frag_pending,pkt_inf->cursor,pkt_inf->lastFragAlign);
				pkt_inf->current_data[g_tx_i]=last_frag_pending;
				pkt_inf->cursor+=pkt_inf->lastFragAlign;
			}//last frag fit in <def>CODING_LENGTH</def>
			else{
				pkt_inf->current_data[g_tx_i]=pkt_inf->cursor;
				pkt_inf->cursor+=CODING_LENGTH;	
			}
			pkt_inf->remain_frag_num--;
			/*debug check*/
			if((pkt_inf->cursor-pkt_inf->data)!=pkt_inf->len){
		        printf("!!!!!!!!!!!NEED DEBUG!!!!!!!!!!!!!!!!!\n");
				printfflush();	
			}
		}
	}
	
    return TRUE;
}
task void ncSendTask(){

/**debug**/
uint16_t debug_addr=0xffff;
/**debug**/
//NOTE: code always do the same
	call Packet.setPayloadLength(&g_msg, sizeof(EncodingHdr_t)+CODING_LENGTH);
	g_tx_payload=call Packet.getPayload(&g_msg, sizeof(EncodingHdr_t)+CODING_LENGTH);
	tx_enc_hdr=(EncodingHdr_t *)g_tx_payload;
	tx_enc_hdr->dispatch=NC_DISPATCH;
	tx_enc_hdr->enc_sn=tx_pkt_inf.enc_sn;
	tx_enc_hdr->g=tx_pkt_inf.current_s;
	tx_enc_hdr->tfn=tx_pkt_inf.total_frag_num;
	
//NOTE END
    //segment length is 1,it is last segment and do NOT need encoding
    //NOTE this MUST be avoided at following version	
	if(tx_pkt_inf.current_m==1){
	    //encoding vector set to NO encoding FLAG 255
	    //NOTE:vector is little than max segment length  <def>MAX_SEGMENT_LENGTH</def>  
	    tx_enc_hdr->i=255;
	    tx_pkt_inf.current_v=tx_enc_hdr->i;
	    tx_enc_hdr->m=tx_pkt_inf.current_m;
	    g_tx_payload+=sizeof(EncodingHdr_t);
	    //
	    my_memcpy(g_tx_payload, tx_pkt_inf.cursor,tx_pkt_inf.lastFragAlign);
	    
	    //printf("debug:m=1 data[1]%u\n",g_tx_payload[1]);
	    //printfflush();
	    //printf("debug:sending vector %d\n",g_encoded_frg_p->vector);
	    //printfflush();
	    if(call AMSend.send(0xffff, &g_msg, sizeof(EncodingHdr_t)+tx_pkt_inf.lastFragAlign) == SUCCESS){
		    //printf("sendTask sending...\n");
		    //printfflush();
	    }else{
		    printf("sendTask FAIL...\n");
		    printfflush();
	    }	
	}//segment length >1 ,segment encoded
	else{
        //get encoded fragment 
	    g_encoded_frg_p=call vc.getNextEncodedFragment();
	    
	    if(g_encoded_frg_p==NULL){
	    //this should not happen
	    //before post ncSendTask,hasNext should be checked.
	        printf("g_encoded_frg_p==NULL\n");
	        printfflush();
	    }else{
	        //set sending encoding vector
	        tx_enc_hdr->i=g_encoded_frg_p->vector;
	        tx_pkt_inf.current_v=g_encoded_frg_p->vector;
	        //set sending segment length
	        tx_enc_hdr->m=tx_pkt_inf.current_m;
	        
	        g_tx_payload+=sizeof(EncodingHdr_t);
	        //copy encoded data
	        my_memcpy(g_tx_payload, (g_encoded_frg_p->Q)->data,CODING_LENGTH);
            //BROAD cast to other nodes
            /**debug**/
            //0,1,2,3,4,5,6,7
            /*
            if(tx_enc_hdr->g==0){
                if(tx_enc_hdr->i==1||tx_enc_hdr->i==2||tx_enc_hdr->i==3||tx_enc_hdr->i==6){
                    debug_addr=0xfffe;
                }
            }
            if(tx_enc_hdr->g==1){
                if(tx_enc_hdr->i==1||tx_enc_hdr->i==2||tx_enc_hdr->i==4||tx_enc_hdr->i==6){
                    debug_addr=0xfffe;
                }
            }
            if(tx_enc_hdr->g==2){
                if(tx_enc_hdr->i==4||tx_enc_hdr->i==5||tx_enc_hdr->i==6||tx_enc_hdr->i==3){
                    debug_addr=0xfffe;
                }
            }
            if(tx_enc_hdr->g==3){
                if(tx_enc_hdr->i==1||tx_enc_hdr->i==2||tx_enc_hdr->i==4||tx_enc_hdr->i==7){
                    debug_addr=0xfffe;
                }
            }
            if((tx_enc_hdr->g&128)==128){
            
                if(tx_enc_hdr->i==2||tx_enc_hdr->i==3||tx_enc_hdr->i==4||tx_enc_hdr->i==5){
	               // debug_addr=0xfffe;
	            }
            }
	        */
	        /**debug**/
	        
	        if(call AMSend.send(debug_addr, &g_msg, sizeof(EncodingHdr_t)+CODING_LENGTH) == SUCCESS){
		        //printf("sendTask sending...\n");
		        //printfflush();
	        }else{
		        printf("sendTask FAIL...\n");
		        printfflush();
	        }
	    }	
    }
}
	
	  
  
task void sendTask(){
    call Packet.setPayloadLength(&g_msg, tx_pkt_inf.len+sizeof(uint8_t));
	g_tx_payload=call Packet.getPayload(&g_msg,tx_pkt_inf.len+sizeof(uint8_t));
	*g_tx_payload=NNC_DISPATCH;
	g_tx_payload+=sizeof(uint8_t);
	
	my_memcpy(g_tx_payload,tx_pkt_inf.data,tx_pkt_inf.len);
	printf("debug:sendTask data[1]%u\n",g_tx_payload[1]);
	    printfflush();
	if(call AMSend.send(0xffff, &g_msg, tx_pkt_inf.len+sizeof(uint8_t)) == SUCCESS){
		printf("sendTask sending...\n");
		printfflush();
	}else{
		printf("sendTask FAIL...\n");
		printfflush();
	}	
	
}

task void rx_decodingTask(){
    if(!call DecodingInfQueue.empty()){
        decoding_inf=call DecodingInfQueue.dequeue();
	    for(dec_i=0;dec_i<decoding_inf->m;dec_i++){
		    decFrags[dec_i].Q=(vdm_data_t *)&rx_data[decoding_inf->offset+dec_i*CODING_LENGTH];
		    decFrags[dec_i].vector=decoding_inf->vectors[dec_i];
	    	//printf("debug:vector==%d\n",decFrags[dec_i].vector);
	    	//printfflush();
	    }
	    call vc.resetDecode();
	    if(call vc.setDecodingData(decFrags,decoding_inf->m)==SUCCESS){
	        //printf("debug:startDecoding\n");
	        //printfflush();
	        
	        if(call vc.startDecoding()==SUCCESS){
		        rx_decoding_task_pedding=TRUE;
		    }else{
		        printf("startDecoding FAIL\n");
		        printfflush();		
		    }
	    }else{
			    printf("setDecodingData FAIL\n");
		        printfflush();		
	    }
    }else{
    
    }
        
}


/******************************************
 *  NC Commands
 ******************************************/
command error_t NC.send(uint8_t * buf, uint16_t len){
// can not conding data longer than <maxNC_LEN> default 1500B
	if(len>maxNC_LEN){
	    printf("WARING!! layer3 packet length is %u, too long\n",len);
		printfflush();
 		return FAIL;
	}
	if(pending==TRUE)
	{   
	    printf("a layer3 packet is still sending...\n");
		printfflush();
		return FAIL;	
	}
	pending=TRUE;
	// do not need fragment 
	if(len<=CODING_LENGTH)
	{
		tx_pkt_inf.data=buf;
		tx_pkt_inf.len=len;
		post sendTask();
		return SUCCESS;
	}else{
	    //set fix info
		tx_pkt_inf.data=buf;
		tx_pkt_inf.cursor=buf;
		tx_pkt_inf.len=len;
		tx_pkt_inf.isPass=FALSE;
		tx_pkt_inf.total_frag_num=div_16_and_ceil(tx_pkt_inf.len,CODING_LENGTH);
		tx_pkt_inf.lastFragAlign=tx_pkt_inf.len%CODING_LENGTH;
		tx_pkt_inf.enc_sn=next_enc_sn();
		//
		tx_pkt_inf.remain_frag_num=tx_pkt_inf.total_frag_num;
		tx_pkt_inf.count=0;
		tx_pkt_inf.current_s=0;
		//prepare firt segment to encode
	    if(next_group(&tx_pkt_inf)==TRUE){
	        //initialize vandermonde encoding
		    call vc.init();
		    //set encoding data
		    if(call vc.setEncodingData(tx_pkt_inf.current_data,tx_pkt_inf.current_m,tx_pkt_inf.current_M)==SUCCESS){
		        //start sending encoded frags
		        
		        post ncSendTask();
		        return SUCCESS;
			}
			else{
				printf("setEncodingData FAIL\n");
	            printfflush();
	            return FAIL;
			}
		}else{//if(next_group(&tx_pkt_inf)!=TRUE){
			//this shoud not happen at first group
			printf("WARING!! first segment has no next segment\n");
		    printfflush();
			return FAIL;
		}
	}	
}
/******************************************
 *		Timer Events	
 ******************************************/
 event void nextSendDelay.fired(){
    post ncSendTask();
 }
event void WaitNextFragTimer.fired(){
    if(rx_decoding_task_pedding==FALSE&&call DecodingInfQueue.empty()){
        printf("debug:WaitNextFragTimer:failReceive\n");
        printfflush();
        signal NC.failReceive(rx_data, rx_pkt_inf.total_frag_num*CODING_LENGTH,rx_segment_map_patten,rx_segment_map);
    }else if(rx_decoding_task_pedding==TRUE){
        //handle in decoding finished
        WaitNextFragTimerFired=TRUE;
    }else if(rx_decoding_task_pedding==FALSE&&!call DecodingInfQueue.empty()){
        printf("debug:WaitNextFragTimer post decodingTask\n");
        printfflush();
        post rx_decodingTask();
    }else{}
}

/******************************************
 *  NC Events
 ******************************************/
event void vc.decodingFinished(vdm_data_t *decodedFrags[],uint8_t m){
    for(dec_i=0;dec_i<m;dec_i++){
        dec_decodedData_p=decodedFrags[dec_i];
        my_memcpy(&rx_data[decoding_inf->offset],dec_decodedData_p->data,CODING_LENGTH);
        //printf("debug:offset:%u\n",&rx_data[decoding_inf->offset]);
        //printfflush();
        decoding_inf->offset+=CODING_LENGTH;
        call vc.copyDecDone(dec_decodedData_p);
    }
    call DecodingInfPool.put(decoding_inf);
    
    if(call DecodingInfQueue.empty()){
	    rx_decoding_task_pedding=FALSE;
	    //all excepted data decoded
	    //printf("debug:rx_map_patten:%u,rx_map:%u\n",rx_segment_map_patten,rx_segment_map);
	    //printfflush();
	    if(rx_segment_map_patten==rx_segment_map){
	        //printf("debug:decodingFinished signal NC.receive\n");
	        //printfflush();
	        signal NC.receive(rx_data, rx_pkt_inf.total_frag_num*CODING_LENGTH);
	        	
	    }//waiting or receiving next segment or 
	    else{
	        if(WaitNextFragTimerFired){
	        /*WARING!! some segment lost   */
	            //printf("debug:decodingFinished:failReceive\n");
                //printfflush();
	            signal NC.failReceive(rx_data, rx_pkt_inf.total_frag_num*CODING_LENGTH,rx_segment_map_patten,rx_segment_map);
	        }
	     
	    }
	}else{
	    printf("debug:decodingFinished post decodingTask\n");
	    printfflush();
		post rx_decodingTask();
	}
 }
/******************************************
 *  AMSend Events
 ******************************************/ 
event void AMSend.sendDone(message_t* msg, error_t err) {
    //printf("debug:senddone: %u %u\n",*((uint8_t *)call Packet.getPayload(msg,80)+sizeof(EncodingHdr_t)),*((uint8_t *)call Packet.getPayload(msg,80)+1+sizeof(EncodingHdr_t)));
    //printfflush();
    //send NC_DISPATCH
    if(tx_pkt_inf.len>CODING_LENGTH){
        //current segment is acknoledged or there is no  encoded frag 
        if(tx_pkt_inf.isACKed||(!call vc.hasNextEncodedFragment())||tx_pkt_inf.current_m==1){
            //move to next segment
      	    if(next_group(&tx_pkt_inf)==TRUE){
      	        //segment number add
                tx_pkt_inf.current_s++;
      	        //segment length is 1,it is last segment and do NOT need encoding
                //NOTE this MUST be avoided at following version
      	        if(tx_pkt_inf.current_m==1){
      	            call nextSendDelay.startOneShot(nextSendInterval);
      	            //post ncSendTask();
      	        }//need encode
      	        else{
      	            call vc.resetEncode();
			        if(call vc.setEncodingData(tx_pkt_inf.current_data,tx_pkt_inf.current_m,tx_pkt_inf.current_M)==SUCCESS){
				        call nextSendDelay.startOneShot(nextSendInterval);
				        //post ncSendTask();
				    }
			        else{
				        printf("setEncodingData FAIL\n");
	                    printfflush();
			        }
			    }		
      	    }//no next segment,all data is sent 
      	    else{
      	        pending=FALSE;
      		    signal NC.sendDone(tx_pkt_inf.data, SUCCESS);
      	    }
        }//send next encoded frag in current segment
        else{
            call nextSendDelay.startOneShot(nextSendInterval);
            //post ncSendTask();
        }
    }//send only one NNC_DISPATCH done
    else{
        pending=FALSE;
    }
        
}
/******************************************
 *  Input
 ******************************************/

void ncInput(uint8_t *buf,uint8_t len){
    //post decoding task after memcpy falg    
    bool postTaskFlag=FALSE;
    bool startTimer=TRUE;
    bool signalReceiveFlag=FALSE;
    rx_enc_hdr=(EncodingHdr_t *)buf;
	buf+=sizeof(EncodingHdr_t);
	len-=sizeof(EncodingHdr_t);
	//if(rx_enc_hdr->g==1){
	printf("debug:enc_sn:%u,segment:%u,m:%u vector:%u\n",rx_enc_hdr->enc_sn,rx_enc_hdr->g,rx_enc_hdr->m,rx_enc_hdr->i);
	printfflush();
	//}
	//following segments in the same layer3 packet
	if(rx_pkt_inf.enc_sn == rx_enc_hdr->enc_sn){
	    //following encoded frag in the same segment
		if(rx_pkt_inf.current_s==(rx_enc_hdr->g&127)){
		    //count receive in the same segment  
		    rx_pkt_inf.count++;
		    //received encoded frags is  not enough to decode
		    
			if(rx_pkt_inf.count < rx_pkt_inf.current_m){
			    //save current receive encoded frag's encoding vector
			    rx_pkt_inf.current_v=rx_enc_hdr->i;
			    
			}//receive enough frags to decode 
			else if(rx_pkt_inf.count == rx_pkt_inf.current_m){
			    //save current receive encoded frag's encoding vector
				rx_pkt_inf.current_v=rx_enc_hdr->i;
				//map current received segment
				rx_segment_map|=1<<rx_pkt_inf.current_s;
				//printf("rx_segment_map==%d\n",rx_segment_map);
				//printfflush();
				
				//send ack and start put int received encoded frags into decoding queue
				//and start decoding if decoding task is not on procedure
				//segment length can not be 1 current_m
				call ACK.sendACKtoSender(rx_pkt_inf.enc_sn,rx_enc_hdr->g);
				
				//last segment flaged by most important bit in segment number
				//printf("debug:enqueue\n");
				//printfflush();
				call DecodingInfQueue.enqueue(decoding_inf_tmp);
				if(rx_decoding_task_pedding==FALSE){
				    postTaskFlag=TRUE;
				}
				//final segment final frag and all segment received do NOT need Timer
				if(rx_pkt_inf.lastGroup&&(rx_segment_map==rx_segment_map_patten)){   
				    startTimer=FALSE;
				}
			}//receive more fragments cased by one hop ack delay	
            else{
			    //printf("receive more fragments cased by ack delay\n");
				//printfflush();
				return;
			}
		}//new encoding segment
		else{
		  //NOTE: WHY need to check last segment receive information
		  //check if last segment receive enough encoded frags
		    //last segment can not decode
		    //NODE:one of layer3 packet's fragments is lost
		    //     in the following version choosing retransmission would be implement 
			if(rx_pkt_inf.count<rx_pkt_inf.current_m){
			    //printf("last group %d lost\n",rx_pkt_inf.current_s);
			    //printfflush();
			    //set decodable flag to rx segment-bit mapping
				rx_segment_map|=0<<rx_pkt_inf.current_s;
				//clear tmp NOTE: this is not necessary
				
				decoding_inf_tmp->enc_sn=0;
				decoding_inf_tmp->offset=0;
				decoding_inf_tmp->m=0;
				memset(decoding_inf_tmp->vectors,255,MAX_SEGMENT_LENGTH);
			}//last segment can be decoded
			else{
			    //map current received segment
				//rx_segment_map|=1<<rx_pkt_inf.current_s;
			    //get new decoding inf
			    decoding_inf_tmp=call DecodingInfPool.get();
				if(decoding_inf_tmp==NULL){
					printf("debug:DecodingInfPool empty\n");
					printfflush();
					return;
				}
			}//check finished
			//first encoded frag of the new segment	
			rx_pkt_inf.count=1;
			rx_pkt_inf.current_s=(rx_enc_hdr->g&127);
			rx_pkt_inf.current_m=rx_enc_hdr->m;
			//printf("current_m=%d \n",rx_pkt_inf.current_m);
		    //printfflush();
			rx_pkt_inf.current_v=rx_enc_hdr->i;
			//check if received frag is the final segment
// WARING!! what about if first frag of final segment lost and the finalSegment flag is not changed
//  and a new layer3 packet is coming.        
			//NOTE: final segment may be all lost
			//      in the following version this should be avoided
			if((rx_enc_hdr->g&128)==128){
			//last group
				rx_pkt_inf.lastGroup=TRUE;	
			}
			//printf("debug:ncInput:rx_pkt_inf.current_s=%u\n",rx_pkt_inf.current_s);
			//printfflush();
			decoding_inf_tmp->enc_sn=rx_pkt_inf.enc_sn;
			decoding_inf_tmp->offset=(rx_pkt_inf.current_s*MAX_SEGMENT_LENGTH)*CODING_LENGTH;
			decoding_inf_tmp->m=rx_pkt_inf.current_m;
			//received frag save memory pointer
			rx_pkt_inf.cursor=&rx_data[decoding_inf_tmp->offset];	
			//final segment only has one frag and do not need encoding
			//and the only one frag is received
    //NOTE in following version this would be avoid by changing segment length  4,1 change to 3,2 or 2,3 
			if(rx_pkt_inf.current_m==1){
			    call ACK.sendACKtoSender(rx_pkt_inf.enc_sn,rx_enc_hdr->g);
			    //put back to pool
			    call DecodingInfPool.put(decoding_inf_tmp);
			    rx_segment_map|=1<<rx_pkt_inf.current_s;
			    if(rx_segment_map==rx_segment_map_patten)
			        startTimer=FALSE;
			    //
			    
			    if(rx_decoding_task_pedding==FALSE&&call DecodingInfQueue.empty()&&(rx_segment_map==rx_segment_map_patten)){
			        signalReceiveFlag=TRUE;
			        
		        }else if(rx_decoding_task_pedding==FALSE&&!call DecodingInfQueue.empty()){
		            postTaskFlag=TRUE;
			        //post rx_decodingTask();	
			    }else{}
			}
		}
	}//new layer3 network coding encoded packet
	else{
//WARING!! last layer3 packet should be checked
//WARING!! continus layers packets sending not be debuged

        //printf("debug: NEW layer3 packet with enc_sn=%d\n",rx_enc_hdr->enc_sn);
	    //printfflush();
	  //first segment of new layer3 packet
		decoding_inf_tmp=call DecodingInfPool.get();
		if(decoding_inf_tmp==NULL){
			printf("debug:DecodingInfPool empty\n");
			printfflush();
			return;
		}
		
	    rx_pkt_inf.isPass=TRUE;
		rx_pkt_inf.enc_sn=rx_enc_hdr->enc_sn;
		//NOTE:this should be removed by "TALK before SEND" or changing network coding header
		//usded by get rx_segment_map_patten
		rx_pkt_inf.total_frag_num=rx_enc_hdr->tfn;
		
		rx_pkt_inf.count=1;
		rx_pkt_inf.current_s=(rx_enc_hdr->g&127);
		rx_pkt_inf.current_m=rx_enc_hdr->m;
		rx_pkt_inf.current_v=rx_enc_hdr->i;
		
		//printf("current_m=%d total_frag_num=%d\n",rx_pkt_inf.current_m,rx_pkt_inf.total_frag_num);
		//printfflush();
		//segment bit mapping patten to check received segement
		switch(((rx_pkt_inf.total_frag_num)/MAX_SEGMENT_LENGTH)+((rx_pkt_inf.total_frag_num%MAX_SEGMENT_LENGTH==0)? 0:1)){
				case 1:	rx_segment_map_patten=1;break;
				case 2:	rx_segment_map_patten=3;break;
				case 3: rx_segment_map_patten=7;break;
				case 4: rx_segment_map_patten=15;break;
				case 5: rx_segment_map_patten=31;break;
				case 6: rx_segment_map_patten=63;break;
				case 7: rx_segment_map_patten=127;break;
				case 8: rx_segment_map_patten=255;break;
		}
		if((rx_enc_hdr->g&128)==128){
			//final segment
		    rx_pkt_inf.lastGroup=TRUE;	
		}
		//NOTE:in current version segment length little than <def>MAX_SEGMENT_LENGTH</def> must be final segment
		//     int the following version non final segment length may be changable
        //if(rx_pkt_inf.current_m<MAX_SEGMENT_LENGTH)rx_pkt_inf.lastGroup=TRUE;	
		decoding_inf_tmp->enc_sn=rx_pkt_inf.enc_sn;
		decoding_inf_tmp->offset=(rx_pkt_inf.current_s*MAX_SEGMENT_LENGTH)*CODING_LENGTH;
		decoding_inf_tmp->m=rx_pkt_inf.current_m;
		rx_pkt_inf.cursor=&rx_data[decoding_inf_tmp->offset]; 	
	}
	//printf("receive group %d vector %d\n",rx_pkt_inf.current_s,rx_pkt_inf.current_v);
	//printfflush();
	//save current received frag encoding vector
	decoding_inf_tmp->vectors[rx_pkt_inf.count-1]=rx_pkt_inf.current_v;
	//save encoded data
	my_memcpy(rx_pkt_inf.cursor,buf,len);

	//move cursor to next encoded frag
	rx_pkt_inf.cursor+=len;
	if(startTimer){
        //start a waitng next fragment timer 
	    call WaitNextFragTimer.startOneShot(WaitNextFragInterval);
	    startTimer=FALSE; 	
	}else{
	    call WaitNextFragTimer.stop();
	}
	if(postTaskFlag){
	    post rx_decodingTask();
	    postTaskFlag=FALSE;
	}
	if(signalReceiveFlag){
        signal NC.receive(rx_data, rx_pkt_inf.total_frag_num*CODING_LENGTH);  
        signalReceiveFlag=FALSE;
    }	
}

void NNCInput(uint8_t *buf,uint16_t len){
    //move NNC_DISPATCH
    buf+=sizeof(uint8_t);
    len-=sizeof(uint8_t);
	my_memcpy(rx_data,buf,len);
	signal NC.receive(rx_data,len);
}


/******************************************
 *  Receive Events
 ******************************************/
event  message_t* Receive.receive(message_t* msg, void* payload,uint8_t len)
{
	uint8_t *p=(uint8_t *)payload;
	//vandermonder encoded frame
	if(*p==NC_DISPATCH){
		ncInput(payload,len);
	}//vandermonder not encoded frame 
	// it is not a network coding frame;
	else if(*p==NNC_DISPATCH){ 
		NNCInput(payload,len);
	}else{
		 // other frames;
	}
  	return msg;
}



/******************************************
 *  ACK Events
 ******************************************/
event void ACK.PacketHasBeenAcked(uint8_t enc_sn,uint8_t g){
	atomic{
		if(tx_pkt_inf.enc_sn==enc_sn&&tx_pkt_inf.current_s==g)
			tx_pkt_inf.isACKed=TRUE;	
			printf("enc_sn %d group %d received\n",enc_sn,g);
			printfflush();
	}
}


/******************************************
 *  ActiveMessageAddress Events
 ******************************************/
async event void ActiveMessageAddress.changed() {

}
  

/******************************************
 *  Interface StdControl
 ******************************************/
	command error_t NCControl.start() 
	{   
	printf("NCControl.start\n");
		  printfflush();
	    call MessageControl.start();
	    call vc.init();
	    return SUCCESS;
	}
	command error_t NCControl.stop()
	{
	    call MessageControl.stop();
	    return SUCCESS;
	}
	event void MessageControl.startDone(error_t err) {
		if (err == SUCCESS) { 
		  printf("MessageControl.startDone SUCCESS\n");
		  printfflush();
			call ACKControl.start();
		}
		else {
		printf("MessageControl.startDone FAIL\n");
		  printfflush();
			call MessageControl.start();
		}
	}
	event void ACKControl.startDone(error_t err){
		if (err == SUCCESS) {
			init();
			printf("ACKControl.startDone SUCCESS\n");
		  printfflush();
			signal NCControl.startDone(err);
		}
		else {
			call ACKControl.start();
		}
	}
	event void ACKControl.stopDone(error_t err){
		 
	}
	event void MessageControl.stopDone(error_t err) {
	   signal NCControl.stopDone(err);
	}

}
