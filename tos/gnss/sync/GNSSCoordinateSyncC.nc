/**
 * Update device location based on data from GPS. Save in persistent storage
 * every 12 hours.
 *
 * NOTE: This module is intended for stationary devices!
 *
 * @author Raido Pahtma
 * @license MIT
 **/
configuration GNSSCoordinateSyncC { }
implementation {

	components new GNSSCoordinateSyncP();

	components TinyHaversineC;

	components GlobalPositioningSystemC;
	GNSSCoordinateSyncP.NotifyCoordinates -> GlobalPositioningSystemC.NotifyCoordinates;

	components LocalTimeSecondC;
	GNSSCoordinateSyncP.LocalTimeSecond -> LocalTimeSecondC;

	components MainC;
	GNSSCoordinateSyncP.Boot -> MainC;

	components DevicePositionParametersC;
	GNSSCoordinateSyncP.GetLatitude  -> DevicePositionParametersC.Latitude;
	GNSSCoordinateSyncP.GetLongitude -> DevicePositionParametersC.Longitude;
	GNSSCoordinateSyncP.GetFixType   -> DevicePositionParametersC.FixType;

	GNSSCoordinateSyncP.SetLatitude  -> DevicePositionParametersC.SetLatitude;
	GNSSCoordinateSyncP.SetLongitude -> DevicePositionParametersC.SetLongitude;
	GNSSCoordinateSyncP.SetFixType   -> DevicePositionParametersC.SetFixType;

	GNSSCoordinateSyncP.SaveLatitude  -> DevicePositionParametersC.SaveLatitude;
	GNSSCoordinateSyncP.SaveLongitude -> DevicePositionParametersC.SaveLongitude;
	GNSSCoordinateSyncP.SaveFixType   -> DevicePositionParametersC.SaveFixType;

}
