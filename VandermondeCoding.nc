#include "VandermondeCoding.h"

interface VandermondeCoding {
	command void init();
/*******************************************************
 *				Encoding 																		 *
 *******************************************************/
  /**
   * set <v>m</v> fragments to be encoded into <v>M</v> Coding Packets 
   * the size of every  fragment is <def>CODING_LENGTH</def> DEFINED IN "VandermndeCoding.h"
   * @param 'uint8_t *data[]' point array to <v>m</v> fragments
   * @param 'uint8_t m' the number of fragments to be encoded
   * @param 'uint8_t M' the number of encoded fragment  after VandermondeCoding
   * @return   ERROR if <var>g_enc_lock</var>.
   */
	command error_t setEncodingData(uint8_t *data[],uint8_t m,uint8_t M);
    /**
	 * @return TRUE if has encoding fragment else FALSE
	 */
	command bool hasNextEncodedFragment();
	/**
	 * get next Vandermonde encoded fragment 
	 * @return pointer of <def>vdm_coding_frag_t</def> if has next
	 * @return NULL after it be called <v>M</v> times
	 */
	command vdm_coding_frag_t * getNextEncodedFragment();

	
	/**
	 * check previous encoding information and clear out it, unlock encoding ,ready for next encode;
	 * @return ERROR if some worng be found
	 */
	command void resetEncode();
	
/*******************************************************
 *				Decoding 																		 *
 *******************************************************/
	/**
   * set <v>m</v> encoding-fragments to be decoded to <v>m</v> fragments 
   * the size of every fragment is <def>CODING_LENGTH</def> DEFINED IN "VandermndeCoding.h"
   * @param data array to <v>m</v> encoding-fragments
   * @param 'uint8_t m' the number of encoding-fragments to be decoded
   * @return   ERROR if decoding is on procedure.
   */
	command error_t setDecodingData(vdm_coding_frag_t data[],uint8_t m);
	
	/**
	 * post a task to decode the set of data
	 * @return SUCCESS if post task successfully, ERROR otherwise
	 */
	command error_t startDecoding();

	/**
	 * Signal the completion of decoding();
	 * @param 'vdm_data_t *decodedFrags[]' point array to <v>m</v> fragments
     * @param 'uint8_t m' the number of fragments decoded
	 */
	event void decodingFinished(vdm_data_t *decodedFrags[],uint8_t m);

	/**
	 * user copy data from pointer which got from getNextFragment()
	 * must be call after memcpy, memory should put back to Pool
	 * @param 'vdm_data_t * p' the coding data 
	 */
	command void copyDecDone(vdm_data_t * p);
	
	/**
	 * check previous encoding information and clear out it, unlock encoding ,ready for next encode;
	 * @return ERROR if some worng be found
	 */
	command void resetDecode();
}
