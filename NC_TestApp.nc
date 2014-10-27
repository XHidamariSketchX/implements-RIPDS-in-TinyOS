#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration NC_TestApp {
}
implementation {
	components MainC;
	components NetworkCodingC as NCC;
	components NC_Test;
	components RandomC;
	  components PrintfC;
  components SerialStartC;
  components new TimerMilliC() as Timer0;
	NC_Test.NCControl->NCC.NCControl;
	NC_Test.NC->NCC.NC;
  NC_Test.Boot->MainC.Boot;
    NC_Test.Random ->RandomC;
  NC_Test.SeedInit ->RandomC;
  NC_Test.nextPacketDelay ->Timer0;
}
