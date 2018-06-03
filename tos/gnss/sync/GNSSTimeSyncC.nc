/**
 * @author Raido Pahtma
 * @license MIT
 **/
configuration GNSSTimeSyncC {
	uses interface Set<uint32_t> as SetNetworkTimeOffset;
}
implementation {

	components new GNSSTimeSyncP();
	GNSSTimeSyncP.SetNetworkTimeOffset = SetNetworkTimeOffset;

	components GlobalPositioningSystemC;
	GNSSTimeSyncP.NotifyTime -> GlobalPositioningSystemC.NotifyTime;

	components RealTimeClockC;
	GNSSTimeSyncP.RealTimeClock -> RealTimeClockC;

	components LocalTimeSecondC;
	GNSSTimeSyncP.LocalTimeSecond -> LocalTimeSecondC;

	components MainC;
	GNSSTimeSyncP.Boot -> MainC;

}
