

#ifndef _VANDERMONDECODING_ 
#define _VANDERMONDECODING_


#define CODING_LENGTH 80
#define MAX_SEGMENT_LENGTH 4
#define MAX_SEGMENT_ENCODING_LENGTH 2*MAX_SEGMENT_LENGTH
//
uint8_t encodingBase[MAX_SEGMENT_ENCODING_LENGTH]={1,2,3,4,5,6,7,8};
typedef struct vdm_data{
	uint8_t data[CODING_LENGTH];
	}vdm_data_t;
typedef struct vdm_coding_frag{
	vdm_data_t *Q;
	uint8_t vector;
	}vdm_coding_frag_t;

#endif



	
