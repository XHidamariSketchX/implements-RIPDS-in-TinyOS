/**
 *	Header for NetworkCoding
 *	@author xuji
 *	@date   2013/7/7
 */
#ifndef ENABLE_PRINTF_DEBUG
#define ENABLE_PRINTF_DEBUG
#endif

#include "VandermondeCoding.h"
#ifndef _NETWORKCODING_ 
#define _NETWORKCODING_
#ifndef CODING_LENGTH 
#define CODING_LENGTH 80
#endif
#define P 95				// assesment of successfully deliver frame over per wireless link 

#define maxNC_LEN 1500 //coding length
#define maxFRAME_NUM 20
#define NC_DISPATCH 0xfe
#define NNC_DISPATCH 0xfd
#define WaitNextFragInterval 1000 //100ms
#define nextSendInterval 10 //5-10ms
enum {
AM_ID_ACK =1,
AM_ID_SEND_INF =2,
AM_ID_NETCODING = 3,
AM_ID_IP_MSG =4,
AM_PKTSENDINF = 10,
NCPool_LEN =2, //IPv6 packet queue length ,every entry's size is maxNC_LEN
IP_PASS=1,
IP_SEND=0
};
typedef nx_struct NC_Packet {
	nx_uint8_t data[maxNC_LEN];
	nx_uint16_t len;
	}NC_Packet_t; 

typedef nx_struct AckPacket {
	nx_uint8_t enc_sn;
	//nx_uint8_t type;//pos,nev
	nx_uint8_t g;
} AckPacket_t;

typedef nx_struct EncodingHdr {
	nx_uint8_t dispatch;		//6LowPAN Dispatch 
    nx_uint8_t enc_sn;			//encoding secquence,the same function as dgram_tag 
    nx_uint8_t g;				// group number 
    nx_uint8_t i;				//enconding vector number
    nx_uint8_t m; 			//frag number in group
    nx_uint8_t tfn;				//origanl fragment number 
}EncodingHdr_t;

typedef struct RxSegmentDecodingInf {
    uint8_t enc_sn;     //encoding sequence for the same layer3 packet
	uint16_t offset;    //first encoded frag of the segment's offset from layer3 rx_data array
	uint8_t m;          //segment length
	uint8_t vectors[MAX_SEGMENT_LENGTH];    //received encoding vectors
}RxSegmentDecodingInf_t;

typedef struct NCSendInf {
	//fix
	uint8_t *data;	//orignal data 
	uint16_t len;		//orignal data length
	bool isPass;		//TRUE current node is relay node FALSE the orignal node
	uint8_t enc_sn;					/* encoding secquence,the same function as dgram_tag */
	uint8_t total_frag_num;							/* origanl fragment number */
	uint8_t lastFragAlign;  /* 0 no align,1-(CODING_LENGTH-1) Bytes align*/
	//changable
	uint8_t *cursor;
	
	uint8_t * current_data[MAX_SEGMENT_LENGTH];
	
	uint8_t remain_frag_num;
	
	uint8_t current_s;							/* group number */
  uint8_t current_v; /* enconding vector number */
	uint8_t current_m;		//frag number in group
  uint8_t current_M;							/* group enconding fragment number */
  bool isACKed;						/* if the packet has been acknowledged */
  bool lastGroup;
  
  uint8_t count;
}NCSendInf_t;
#endif
	
