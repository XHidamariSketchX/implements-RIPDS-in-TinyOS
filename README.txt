/**
 * PARTLY implement of RFC4944 and RIPDS version1.0 
 * @author xuji
 * @date 2013/4/26
 * 
 * experiment result see log.txt
 */

*************************************************************************************************************************
P=0.95
LINK_DATA_MTU=110
DATAGRAM_SIZE=1500

128bit IPv6 address { IPv6_PF:IPv6_ID }=fe:80::ff:fe:00:{short_address}

l0=LINK_DATA_MTU-sizeof{NC_DISPATCH +enc_sn +  i  +  m }
m=¡ºDATAGRAM_SIZE/l0¡º
M=m*¡º1/P¡º
             
*****************************Coding Fragment*****************************************************************************

            octets              DATAGRAM_SIZE
                  +------+------+------------------+-----+  
IPv6_PKT          |  k1  |  k2  |     ........     | km  |
                  +------+------+------------------+-----+
                  
            octets    11            1          1       1     1      {l0}      2
                  +-----------+-------------+-------+-----+-----+----------+----+
For each Frame    |  MAC_Hdr  | NC_DISPATCH |enc_sn |  i  |  m  |    Qi    |FCS |
                  +-----------+-------------+-------+-----+-----+----------+----+
  i++                         
         

          
            octets  2   1     2     2    2          1     1
                  +---+---+-------+----+---+    +-------+----+
MAC_Hdr:          |fcf|dsn|destpan|dest|src|  + |network|type|
                  +---+---+-------+----+---+    +-------+----+ 
                       802.15.4 Hdr          tinyos ActiveMessage Hdr       

                                                      
*****************************ACK Frame*****************************************************************************
            octets     11         1     2
                  +-----------+------+---+
ACK Frame         |  MAC_Hdr  |enc_sn|FCS|
                  +-----------+------+---+      
enc_sn :which IPv6_PKT to ACK


      
*****************************************************************************************************************


 1         {short_address}
¡ñ             node


------i->   next hop receive i coding frame

NOTE :Next hop will receive more than <m> frames 
      During the next hop send  MY ACK frame and the frame to be received by forward hop
      Forward hop should continue  send coding frame
      IT shows next hop will receive more two or three coding frame 
      
node 1 IPv6 address fe:80::ff:fe:00:01
node 2 IPv6 address fe:80::ff:fe:00:02
node 3 IPv6 address fe:80::ff:fe:00:03
                
Every second the soure node 1 send App_DATA to Destionation node 3
                  
                  1       2         3
*****1th App_DATA ¡ñ      ¡ñ       ¡ñ             ***** 
  ¡ü              ------1->                         ¡ü
  ¡ü              ------2->                         ¡ü
  ¡ü                    .                           ¡ü
  ¡ü                    .                           ¡ü
  ¡ü                    .                           ¡ü
  ¡ü              ------m->                         ¡ü
  ¡ü              ¡ñ<_ACK_¡ñ       ¡ñ               
                            ------1->           ¡Ö750-950ms 
                            ------2->               
                                  .
1000ms                            .                 ¡ý
                                  .                 ¡ý
                            ------m->               ¡ý
                                                    ¡ý
                          ¡ñ<___ACK_¡ñ              ¡ý
  ¡ý              ¡ñ<___AC¡ñK______¡¹             *****
  ¡ý                      
  ¡ý    
  ¡ý    
  ¡ý    
  ¡ý    
  ¡ý    
  ¡ý              1       2         3
*****             ¡ñ      ¡ñ       ¡ñ
                  ------1->
                  ------2->
                        .
                        .
                        .
                  ------m->
                  ¡ñ<_ACK_¡ñ       ¡ñ
            .
            .
            .
            .
            .
            .
            .
    20th App_DATA 
**********************************************************************************************************************                
