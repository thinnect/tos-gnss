/**
 * Update device location based on data from GPS. Save in persistent storage
 * every 12 hours.
 *
 * NOTE: This module is intended for stationary devices!
 *
 * @author Raido Pahtma
 * @license MIT
 **/
#include "DeviceParameters.h"
#include "tiny_haversine.h"
generic module GNSSCoordinateSyncP() {
	uses {
		interface Notify<nmea_coordinates_t*> as NotifyCoordinates;
		interface LocalTime<TSecond> as LocalTimeSecond;

		interface Get<int32_t> as GetLatitude;
		interface Set<int32_t> as SetLatitude;
		interface Set<int32_t> as SaveLatitude;

		interface Get<int32_t> as GetLongitude;
		interface Set<int32_t> as SetLongitude;
		interface Set<int32_t> as SaveLongitude;

		interface Get<char> as GetFixType;
		interface Set<char> as SetFixType;
		interface Set<char> as SaveFixType;

		interface Boot @exactlyonce();
	}
}
implementation {

	#define __MODUUL__ "gnsscs"
	#define __LOG_LEVEL__ (LOG_LEVEL_GNSSCoordinateSyncP & BASE_LOG_LEVEL)
	#include "log.h"

	uint32_t m_saved = 0;

	int32_t m_avg_latitude = 0;
	int32_t m_avg_longitude = 0;
	uint16_t m_avg_count = 0; // Reset every 12 hours

	event void Boot.booted() {
		call NotifyCoordinates.enable();
	}

	// Take the (d)ddmm.mmmmm format and convert to dd.dddddd * 10E6
	int32_t convert_nmea_to_degrees(int32_t ddmm_mmmm) {
		int32_t degrees = ddmm_mmmm / 1E6L;
		degrees *= 1E6L; // Separate line, so compiler would not get rid of div and multiply with same number?
		return degrees + 100*(ddmm_mmmm - degrees)/60;
	}

	event void NotifyCoordinates.notify(nmea_coordinates_t* coords) {
		if((coords->mode == 'A')||(coords->mode == 'D')) {
			int64_t sum_latitude = (int64_t)m_avg_latitude*m_avg_count + convert_nmea_to_degrees(coords->latitude);
			int64_t sum_longitude = (int64_t)m_avg_longitude*m_avg_count + convert_nmea_to_degrees(coords->longitude);
			m_avg_count++;

			m_avg_latitude = sum_latitude / m_avg_count;
			m_avg_longitude = sum_longitude / m_avg_count;

			if(call GetFixType.get() == 'F') {
				uint32_t distance = tiny_haversine(call GetLatitude.get(), call GetLongitude.get(), m_avg_latitude, m_avg_longitude);
				if(distance < 1000) {
					return; // Coords line up, keep using fixed coords.
				}
				else warn1("fob %"PRIu32, distance);
			}

			// Save coordinates one hour after bootup and every 12 hours after that
			if((call LocalTimeSecond.get() > 3600UL)
			 &&((m_saved == 0)||(call LocalTimeSecond.get() - m_saved > 12*3600UL))) {
				m_saved = call LocalTimeSecond.get();
				m_avg_count = 1; // Reset averaging

				info1("%"PRIi32"; %"PRIi32, m_avg_latitude, m_avg_longitude);
				call SaveLatitude.set(m_avg_latitude);
				call SaveLongitude.set(m_avg_longitude);
				call SaveFixType.set('A'); // Saving A, require actual fix after boot
			}
			else {
				debug1("%"PRIi32"; %"PRIi32, m_avg_latitude, m_avg_longitude);
				call SetLatitude.set(m_avg_latitude);
				call SetLongitude.set(m_avg_longitude);
			}
			call SetFixType.set('G'); // Always set fix type to G
		}
	}

}
