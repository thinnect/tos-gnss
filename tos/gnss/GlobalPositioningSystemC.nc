/**
 * @author Raido Pahtma
 * @license MIT
 **/
#include "tiny_nmea.h"
configuration GlobalPositioningSystemC {
	provides {
		interface SplitControl;
		interface Notify<time64_t> as NotifyTime;
		interface Notify<nmea_coordinates_t*> as NotifyCoordinates;
	}
}
implementation {

	components new GlobalPositioningSystemP() as GNSS;
	SplitControl = GNSS.SplitControl;
	NotifyTime = GNSS.NotifyTime;
	NotifyCoordinates = GNSS.NotifyCoordinates;

	components Atm128Uart1C as Uart1;
	GNSS.BaudRate      -> Uart1.UartBaudRate;
	GNSS.SerialControl -> Uart1.StdControl;
	GNSS.UartStream    -> Uart1.UartStream;
	GNSS.UartByte      -> Uart1.UartByte;

	components AtmegaGeneralIOC;
	GNSS.Reset -> AtmegaGeneralIOC.PortE6;

	components new TimerMilliC();
	GNSS.Timer -> TimerMilliC;

	components DeviceParametersC;
	DeviceParametersC.DeviceParameter[UQ_DEVICE_PARAMETER_SEQNUM] -> GNSS.ModuleInfoParameter;

}
