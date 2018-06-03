/**
 * @author Raido Pahtma
 * @license MIT
 **/
#include "DeviceParameters.h"
generic module GNSSTimeSyncP() {
	uses {
		interface Notify<time64_t> as NotifyTime;
		interface RealTimeClock;
		interface LocalTime<TSecond> as LocalTimeSecond;
		interface Set<uint32_t> as SetNetworkTimeOffset;
		interface Boot @exactlyonce();
	}
}
implementation {

	#define __MODUUL__ "gnssts"
	#define __LOG_LEVEL__ (LOG_LEVEL_GNSSTimeSyncP & BASE_LOG_LEVEL)
	#include "log.h"

	uint32_t m_updated = 0;

	event void Boot.booted() {
		call NotifyTime.enable();
	}

	event void NotifyTime.notify(time64_t t) {
		if(t != (time64_t)(-1)) {
			time64_t rtc = call RealTimeClock.time();
			uint32_t now = call LocalTimeSecond.get();
			if((rtc == (time64_t)(-1)) || (now - m_updated > 60)) { // Limit updates to once a minute
				error_t err = call RealTimeClock.stime(t);
				if(err == SUCCESS) {
					uint32_t yxko = yxktime(&t) - now;
					call SetNetworkTimeOffset.set(yxko);
					m_updated = now;
					info1("%"PRIu32, (uint32_t)t);
				}
			}
			else debug1("%"PRIu32" x %"PRIu32, (uint32_t)rtc, (uint32_t)t);
		}
	}

	async event void RealTimeClock.changed(time64_t old, time64_t current) { }

	default command void SetNetworkTimeOffset.set(uint32_t value) { /* Network time offset setting is optional */ }

}
