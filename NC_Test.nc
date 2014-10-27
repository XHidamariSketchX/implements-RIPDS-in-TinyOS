
#include "printf.h"
#include "test_IP.h"
module NC_Test {
	uses interface Boot;
	uses interface NC;
	uses interface SplitControl as NCControl;
    uses interface Random;
    uses interface Timer<TMilli> as nextPacketDelay;
    uses interface ParameterInit<uint16_t> as SeedInit;
}implementation{
	uint8_t data[1500];
	uint16_t sendDataLen=0;
	ipv6_hdr_t * ip_hdr;
	uint16_t i;
	bool debug_isWrong=FALSE;
	uint16_t debug_count=0;
	uint8_t debug_tmp;
	uint8_t debug_i;
	uint8_t debug_g;
	uint8_t debug_j;
event void Boot.booted() {
    printf("booted\n");
    printfflush();
    call NCControl.start();
} 
event void NCControl.startDone(error_t err) {
    if(err==SUCCESS){
        call SeedInit.init(6);
        for(i=0;i<1500;i++){
            data[i]=(call Random.rand16())%256;
            //data[i]=55;
        }
        if(TOS_NODE_ID==1){
            printf("this is SOURCE node\n");
            printfflush();
            /*
            ip_hdr=(ipv6_hdr_t *)&data[0];
            ip_hdr->V_TC_FL=0;
            ip_hdr->V_TC_FL|=6<<28;
            ip_hdr->payload_len=1500-40;
            ip_hdr->hop_limit=2;
            ip_hdr->src_addr[15]=1;
            ip_hdr->dst_addr[15]=1;
            */
            sendDataLen=80*10-20;
            if(call NC.send(data,sendDataLen)==SUCCESS){
	            printf("NC_send SUCCESS\n");
	            printfflush();
	        }else{
	            printf("NC_send FAIL\n");
	            printfflush();
	        }
        }else{
            printf("this is RELAY node\n");
            printfflush();
        }
    }else{
        printf("NC Start FAIL\n");
        printfflush();
        call NCControl.start();
    }
//END of startDone
}
event void nextPacketDelay.fired(){
if(call NC.send(data,sendDataLen)==SUCCESS){
	            printf("send second SUCCESS\n");
	            printfflush();
	        }else{
	            printf("NC_send FAIL\n");
	            printfflush();
	        }

}
  event void NC.sendDone(uint8_t *buf, error_t error){
    printf("NC_sendDone\n");
    printfflush();
    //call nextPacketDelay.startOneShot(2000);
    
  }
event void NC.failReceive(uint8_t * buf ,uint16_t len, uint8_t rx_segment_map_patten,uint8_t rx_segment_map){
    uint8_t p_i;
    uint8_t tmp=0;
    printf("NC_failReceive\n");
    printf("expected to receive segment:\n");
    printfflush();
    for(p_i=0;p_i<8;p_i++){
        tmp=1<<p_i;
        if(rx_segment_map_patten&tmp){
            printf("%u,",p_i);
        } 
    }
    printf("\n");
    printf("receive segment:\n");
    printfflush();
    for(p_i=0;p_i<8;p_i++){
        tmp=1<<p_i;
        if(rx_segment_map&tmp){
            printf("%u,",p_i);
        }
    }
    printf("\n");
    printfflush();
}
event void NC.receive(uint8_t * buf, uint16_t len){
uint16_t errC=0;
    for(i=0;i<len;i++){
        if(data[i]!=buf[i]){
            errC++;
            //printf("%u",buf[i]);
        }
    }
    printf("receive layer3 packet length=%u Bytes, error Bytes=%u\n",len,errC);
    printfflush();
	
}
	
event void NCControl.stopDone(error_t err){
		 printf("NCControl.stopDone\n");
    printfflush();
}
//END of implemention
}
