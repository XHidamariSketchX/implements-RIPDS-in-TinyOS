/**
 *	interface of acknowledge
 *	@author xuji
 *	@date   2013/7/7
 */
interface ACK {

event void PacketHasBeenAcked(uint8_t enc_sn,uint8_t g);

command void sendACKtoSender(uint8_t enc_sn,uint8_t g);

}
