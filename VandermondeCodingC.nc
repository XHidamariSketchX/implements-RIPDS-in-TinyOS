#include "VandermondeCoding.h"

module VandermondeCodingC {
	provides interface VandermondeCoding as vc;
	uses interface Pool<vdm_data_t> as VdmDataPool;
}
implementation{
/********************************************************************
 *							Global Variables																		* 
 ********************************************************************/
 // Encoding Variables
 	uint8_t g_enc_i,g_enc_j;
 	uint8_t g_enc_vector;
 	bool g_enc_lock=FALSE;
	uint8_t **g_enc_data;
	uint8_t g_enc_m;
	uint8_t g_enc_M;
	vdm_coding_frag_t g_encoded_frag;
	vdm_data_t g_encoded_data;
	
 //Decoding Variables
 	uint8_t g_dec_i,g_dec_j;
 	uint8_t g_dec_vdm_matrix[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH];
 	uint8_t g_dec_vdmDec_matrix[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH];
 	bool g_is_decoding=FALSE;
 	bool g_dec_lock=TRUE;
	uint8_t g_dec_m;
	vdm_coding_frag_t *g_dec_tmp; 
	vdm_coding_frag_t *g_dec_data;
	vdm_data_t *g_decodedFrags[MAX_SEGMENT_LENGTH];	

	
	
/********************************************************************
 *							Tools																								* 
 ********************************************************************/
 void   clear_vdm_data_t(vdm_data_t *p);
 uint8_t multip(uint8_t c1,uint8_t c2);
 uint8_t power (uint8_t x,uint8_t y);
 void getM(uint8_t m[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH],uint8_t i,uint8_t j,uint8_t n,uint8_t rm[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH]);
 uint8_t detm(uint8_t m[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH],uint8_t n);
 uint8_t hasReverse(uint8_t r);
 void get_g_dec_vdmDec_matrix();
 uint8_t getEncodingData(uint8_t p,uint8_t vector);
 uint8_t getDecodingData(uint8_t p,uint8_t dec_index);
 

/********************************************************************
 *							Tasks																								* 
 ********************************************************************/
 task void decodeTask(){
 		for(g_dec_i=0;g_dec_i<g_dec_m;g_dec_i++){
 			g_dec_tmp=&g_dec_data[g_dec_i];
 			if(g_dec_tmp==NULL){
 			    printf("g_dec_tmp==NULL\n");
 			    printfflush();
 			}else{
 				//get receive encoding matrix
 				for(g_dec_j=0;g_dec_j<g_dec_m;g_dec_j++){
 				    g_dec_vdm_matrix[g_dec_i][g_dec_j]=power(encodingBase[g_dec_tmp->vector],g_dec_j);
 			        //printf("][%u ",g_dec_vdm_matrix[g_dec_i][g_dec_j]);
 				}
 				//printf("\n");
 				
 			}	
 		}
 		printfflush();
 		//get decoding matrix
 		get_g_dec_vdmDec_matrix();
 	
 		//decoding
 		
 		for(g_dec_i=0;g_dec_i<g_dec_m;g_dec_i++){
 				for(g_dec_j=0;g_dec_j<CODING_LENGTH;g_dec_j++){
 					g_decodedFrags[g_dec_i]->data[g_dec_j]=getDecodingData(g_dec_j,g_dec_i);
 				}
 		}
 		signal vc.decodingFinished(g_decodedFrags,g_dec_m);
 		
 }
/********************************************************************
 *							VandermondeCoding Commands and Events	* 
 ********************************************************************/
	command void vc.init(){
		g_enc_i=0;
		g_enc_j=0;
		g_enc_vector=0;
		g_enc_data=NULL;
		g_enc_m=0;
		g_enc_M=0;
		g_enc_lock=FALSE;
		g_encoded_frag.Q=&g_encoded_data;
	}
 /************* Encoding***************/
	command error_t vc.setEncodingData(uint8_t *data[],uint8_t m,uint8_t M){		
		if(m>MAX_SEGMENT_LENGTH||m<2){
			return FAIL;	
		}
		if(m>M){
			return FAIL;
		}
		if(M>MAX_SEGMENT_ENCODING_LENGTH)
			return FAIL;
		if(g_enc_lock)
			return FAIL;
		
		g_enc_data=data;
		g_enc_m=m;
		g_enc_M=M;
		g_enc_lock=TRUE;
		return SUCCESS;
	}

	command vdm_coding_frag_t * vc.getNextEncodedFragment(){
		if(g_enc_vector>=g_enc_M)
			return NULL;
		g_encoded_frag.vector=g_enc_vector;
		for(g_enc_j=0;g_enc_j<CODING_LENGTH;g_enc_j++){
 			((g_encoded_frag.Q)->data)[g_enc_j]=getEncodingData(g_enc_j,g_enc_vector);	
 		}
		g_enc_vector++;
		return &g_encoded_frag;
	}
	command bool vc.hasNextEncodedFragment(){
	    if(g_enc_vector<g_enc_M)return TRUE;
	    else return FALSE;
	}
	command void vc.resetEncode(){
		g_enc_vector=0;
		g_enc_data=NULL;
		g_enc_m=0;
		g_enc_M=0;
		g_encoded_frag.Q=&g_encoded_data;
		g_enc_lock=FALSE;
	}
 /************* Decoding***************/ 	
	command error_t vc.setDecodingData(vdm_coding_frag_t data[],uint8_t m){
		// An decoding task is on produce
		if(g_dec_lock==TRUE)
			return FAIL;

		if(m>MAX_SEGMENT_LENGTH||m<2)
			return FAIL;
		// There is not enough memory in the pool for decoding
		if(call VdmDataPool.size()<m)
			return FAIL;
		//prepare decoding memory
		for(g_dec_i=0;g_dec_i<m;g_dec_i++){
			g_decodedFrags[g_dec_i]=call VdmDataPool.get();	//NOTE VdmDataPool.put() should be called
			if(g_decodedFrags[g_dec_i]==NULL){
			  printf("VdmDataPool empty\n");
			  printfflush();
			  return FAIL;
			}
		}
		g_dec_data=data;
		g_dec_m=m;
		return SUCCESS;
	}
	command error_t vc.startDecoding(){
		if(g_dec_lock==TRUE)
			return FAIL;
		g_is_decoding=TRUE;
		g_dec_lock=TRUE;
		post decodeTask();
		return SUCCESS;
	}
	command void vc.copyDecDone(vdm_data_t * p){
		clear_vdm_data_t(p);
		call VdmDataPool.put(p);
	}
	command void vc.resetDecode(){
		g_dec_i=0;
		g_dec_j=0;
		g_dec_m=0;
		g_is_decoding=FALSE;
 		g_dec_lock=FALSE;
	}

void  clear_vdm_data_t(vdm_data_t *p){
	memset(p,0,sizeof(vdm_data_t))	;
}

uint8_t multip(uint8_t c1,uint8_t c2){
	uint8_t tmp=0;
	uint8_t mask=1;
	uint8_t mask2=1;
	uint8_t value=0;
	uint8_t i;
	uint8_t j;
	if(c1==0||c2==0)return 0;
	for(i=0;i<8;i++){
	
		if(mask&c2){
			tmp=c1>>(8-i);
			value=value^(c1<<i);
			mask2=1;
			for(j=0;j<i;j++){
				if(mask2&tmp){
					switch(j){ 
					    case 0:value^=27;break;
						case 1:value^=54;break;
						case 2:value^=108;break;
						case 3:value^=216;break;
						case 4:value^=171;break;
						case 5:value^=77;break;
						case 6:value^=154;break;
						case 7:value^=57;break;
						default : break;
					/*
						case 0:{
						
						//value=value^27;
						
						}break;
						case 1:{value^=54;
						    //printf("%u\n",value);
						//printfflush();
						}break;
						case 2:value^=108;break;
						case 3:value^=216;break;
						//case 4:value^=171;break;
						
						//case 5:value^=77;break;
						case 6:value^=154;break;
						case 7:value^=57;break;
						default : break;
					*/
					}
				}
				mask2=mask2<<1;
			}
		}
		mask=mask<<1;
		
	}
	
	return value;
}

uint8_t power (uint8_t x,uint8_t y){
	uint8_t r;
	uint8_t i;
	if(y==0)
		return 1;
	else if(y==1){
		return x;
	}
	else{
		r=x;
		for(i=0;i<y-1;i++){
			r=multip(x,r);
		}
		return r;
	}	 
}


void getM(uint8_t m[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH],uint8_t i,uint8_t j,uint8_t n,uint8_t rm[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH]){
	uint8_t p,q;
	uint8_t s=0;
	for(p=0;p<n;p++){
		for(q=0;q<n;q++)
		{
			if(q!=j&&p!=i){
			  //printf("[%d][%d]=%d",s/(n-1),s%(n-1),rm[s/(n-1)][s%(n-1)]);
				rm[s/(n-1)][s%(n-1)]=m[p][q];
				s++;
			}
		}
	
	}

}
uint8_t detm(uint8_t m[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH],uint8_t n){
	uint8_t tmp[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH];
	uint8_t v=0;
	uint8_t i=0;
	if(n==1)
		return m[0][0];
	if(n==2){
		return multip(m[0][0],m[1][1])^multip(m[0][1],m[1][0]);
	}else{
		for(i=0;i<n;i++){
			getM(m,i,0,n,tmp);
			v^=multip(m[i][0],detm(tmp,n-1));
		}
		return v;
	}
}
uint8_t hasReverse(uint8_t r){
	uint8_t tmp;
	uint16_t i;
	if(r==0)return 0;
	for(i=0;i<256;i++){
		tmp=multip(r,i);
		if(tmp==1){
			return i;
		}
	}
	return 0;
}
void get_g_dec_vdmDec_matrix(){
	uint8_t r;
	uint8_t rev;
	uint8_t tmp[MAX_SEGMENT_LENGTH][MAX_SEGMENT_LENGTH];
	uint8_t tmp_r;
	
	r=detm(g_dec_vdm_matrix,g_dec_m);
	
	rev=hasReverse(r);
	if(r==0||rev==0){
		printf("r=%d\n",r);
		printf("rev=%d\n",rev);
		printfflush();
	}
	
	for(g_dec_i=0;g_dec_i<g_dec_m;g_dec_i++){
 		for(g_dec_j=0;g_dec_j<g_dec_m;g_dec_j++){
 			getM(g_dec_vdm_matrix,g_dec_j,g_dec_i,g_dec_m,tmp);
			tmp_r=detm(tmp,g_dec_m-1);
			tmp_r=multip(tmp_r,rev);
			//printf("][%u ",tmp_r);
 			g_dec_vdmDec_matrix[g_dec_i][g_dec_j]=tmp_r;
 		}
 		//printf("\n");	
 	}
 	//printfflush();
}
uint8_t getEncodingData(uint8_t p,uint8_t vector){
	uint8_t r=0;
	uint8_t i=0;
	for(i=0;i<g_enc_m;i++){   
	  r^=multip(power(encodingBase[vector],i),g_enc_data[i][p]);
	}
	return r;
}
uint8_t getDecodingData(uint8_t p,uint8_t dec_index){
	uint8_t r=0;
	uint8_t i=0;
	for(i=0;i<g_dec_m;i++){
	    /*if((g_dec_m==2)&&p==1){
	    printf("debug:VDM:%u,%u\n",g_dec_vdmDec_matrix[dec_index][i],((g_dec_data[i].Q)->data)[p]);
	    printfflush();}*/
	    //if(g_dec_m==4)
		r^=multip(g_dec_vdmDec_matrix[dec_index][i],((g_dec_data[i].Q)->data)[p]);
	}
	return r;
}
}
