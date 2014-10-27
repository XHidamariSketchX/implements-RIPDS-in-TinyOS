/**
 *	interface of NetworkCoding
 *	@author xuji
 *	@date   2013/7/7
 */

interface NC {

/**
 *	
 *	buf : the start point of a block data to be send
 *  len : the size of the block
 */
	command error_t send(uint8_t * buf, uint16_t len);
	event void sendDone(uint8_t *buf, error_t error);
	
	event void receive(uint8_t * buf, uint16_t len);
    event void failReceive(uint8_t * buf ,uint16_t len, uint8_t rx_segment_map_patten,uint8_t rx_segment_map);
}
