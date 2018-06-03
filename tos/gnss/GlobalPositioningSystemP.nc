/**
 * @author Raido Pahtma
 * @license MIT
 **/
#include "tiny_nmea.h"
#include "test_tiny_nmea.h"
#include "DeviceParameters.h"
generic module GlobalPositioningSystemP() {
	provides {
		interface SplitControl;
		interface Notify<time64_t> as NotifyTime;
		interface Notify<nmea_coordinates_t*> as NotifyCoordinates;

		interface DeviceParameter as ModuleInfoParameter;
	}
	uses {
 		interface StdControl as SerialControl;
 		interface GetSet<uint32_t> as BaudRate;

 		interface GeneralIO as Reset;

		interface UartByte;
		interface UartStream;

		interface Timer<TMilli>;
	}
}
implementation {

	#define __MODUUL__ "GNSS"
	#define __LOG_LEVEL__ (LOG_LEVEL_GlobalPositioningSystemP & BASE_LOG_LEVEL)
	#include "log.h"

	norace char m_rx[81]; // NMEA sentence can be 80 characters + \r\n + \0, \r\n get discarded in receive, so 80+2+1-2
	norace uint8_t m_received = 0;

	PROGMEM const char m_q_fw[]   = "$PMTK605*31\r\n";
	PROGMEM const char m_p_txt[]  = "$PQTXT,W,0,0*22\r\n";
	PROGMEM const char m_p_rate[] = "$PMTK314,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*2D\r\n";
	//PROGMEM const char m_p_rate[]="$PMTK314,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*29\r\n";
	//PROGMEM const char m_p_easy[]="$PMTK869,1,1*35\r\n";

	char m_tx[sizeof(m_p_rate)]; // sizeof largest command string

	enum GNSSSetupStates {
		ST_OFF,
		ST_Q_MOD_INFO,
		ST_P_TXT_CONF,
		ST_P_GPS_RATE,
		ST_LAST
	};

	typedef struct gnss_module_state {
		uint8_t state      : 6;
		bool notify_time   : 1;
		bool notify_coords : 1;
	} gnss_module_state_t;

	gnss_module_state_t m = { ST_OFF, FALSE, FALSE };

	char m_module_info[64]; // Store module info string

	command error_t NotifyTime.enable() {
		m.notify_time = TRUE;
		return SUCCESS;
	}
	command error_t NotifyTime.disable() {
		m.notify_time = FALSE;
		return SUCCESS;
	}
	command error_t NotifyCoordinates.enable() {
		m.notify_coords = TRUE;
		return SUCCESS;
	}
	command error_t NotifyCoordinates.disable() {
		m.notify_coords = FALSE;
		return SUCCESS;
	}

	command error_t SplitControl.start() {
		if(test_tiny_nmea()) debug1("nmea tests pass");
		else err1("nmea tests fail");

		if(m.state == ST_OFF) {
			error_t err;
			call BaudRate.set(9600UL);
			err = call SerialControl.start();
			logger(err == SUCCESS ? LOG_DEBUG1: LOG_ERR1, "start=%d", err);
			if(err == SUCCESS) {
				call Reset.makeOutput();
				call Reset.set();

				call UartStream.enableReceiveInterrupt();

				m.state = ST_Q_MOD_INFO;

				call Timer.startOneShot(1000UL);

				return SUCCESS;
			}
		}
		return FAIL;
	}

	task void stopDone() {
		call Reset.clr();
		call UartStream.disableReceiveInterrupt();
		call Timer.stop();
		call SerialControl.stop();
		m.state = ST_OFF;
		signal SplitControl.stopDone(SUCCESS);
	}

	command error_t SplitControl.stop() {
		return post stopDone();
	}

	task void received() {
		m_rx[m_received] = '\0';
		if(m.state < ST_LAST) {
			bool success = FALSE;
			if(nmea_checksum_ok(m_rx, m_received)) {
				switch(m.state) {
					case ST_Q_MOD_INFO: { // $PMTK705,AXN_3.8_3333_15110900,0002,Quectel-L86,1.0*0D
						static const char r[] PROGMEM = "$PMTK705";
						if(memcmp_P(m_rx, r, strlen_P(r)) == 0) {
							uint8_t len = m_received-9-3;
							if(len >= sizeof(m_module_info)) {
								len = sizeof(m_module_info) - 1;
							}
							memcpy(m_module_info, &(m_rx[9]), len);
							memset(&m_module_info[len], 0, sizeof(m_module_info)-len);
							debug1("MOD: %s", m_module_info);
							success = TRUE;
						}
						break;
					}
					case ST_P_TXT_CONF: { // $PQTXT,W,OK*0A
						static const char r[] PROGMEM = "$PQTXT,W,OK";
						if(memcmp_P(m_rx, r, strlen_P(r)) == 0) {
							success = TRUE;
						}
						break;
					}
					case ST_P_GPS_RATE: { // $PMTK001,314,3*36
						static const char r[] PROGMEM = "$PMTK001,314,3";
						if(memcmp_P(m_rx, r, strlen_P(r)) == 0) {
							success = TRUE;
						}
						break;
					}
				}
			}
			if(success) {
				m.state++;
				call Timer.startOneShot(1);
			}
			else {
				debug1("NMEA: %s", m_rx);
				if(call Timer.isRunning() == FALSE) {
					call Timer.startOneShot(1000);
				}
			}
		}
		else {
			nmea_coordinates_t coords;
			struct tm tm;
			int err = nmea_parse(m.notify_coords ? &coords: NULL,
			                     m.notify_time   ? &tm:      NULL,
			                     NULL, m_rx, m_received);
			if(err == 0) {
				// debug1("NMEA: %s", m_rx);
				if(m.notify_coords) {
					info1("GPS: %"PRIi32";%"PRIi32" m=%c", coords.latitude, coords.longitude, coords.mode);
					signal NotifyCoordinates.notify(&coords);
				}
				if(m.notify_time) {
					time64_t t = mktime(&tm);
					info1("tm : %04u-%02u-%02u %02u:%02u:%02u %"PRIu32, tm.tm_year+1900, tm.tm_mon+1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec, (uint32_t)t);
					signal NotifyTime.notify(t);
				}
			}
			else {
				warn1("NMEA (%d): %s", err, m_rx);
			}
		}
		m_received = 0;
		call UartStream.enableReceiveInterrupt();
	}

	event void Timer.fired() {
		uint8_t len = 0;
		switch(m.state) {
			case ST_Q_MOD_INFO:
				len = strlen_P(m_q_fw);
				memcpy_P(m_tx, m_q_fw, len);
			break;
			case ST_P_TXT_CONF:
				len = strlen_P(m_p_txt);
				memcpy_P(m_tx, m_p_txt, len);
			break;
			case ST_P_GPS_RATE:
				len = strlen_P(m_p_rate);
				memcpy_P(m_tx, m_p_rate, len);
			break;
			default:
				signal SplitControl.startDone(SUCCESS);
				return;
			break;
		}
		call UartStream.send((uint8_t*)m_tx, len);
		call Timer.startOneShot(1000);
	}

	async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t error) {
		debug1("snt %d %d", len, error);
	}

	async event void UartStream.receivedByte(uint8_t byte) {
		if((m_received == 0)&&(byte != '$')) { // Sentence must start with $
			return;
		}

		if(m_received < sizeof(m_rx)) {
			if((byte == '\r')||(byte == '\n')) {
				call UartStream.disableReceiveInterrupt();
				post received();
			}
			else {
				m_rx[m_received++] = (char)byte;
			}
		}
		else {
			m_received = 0;
		}
	}

	async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t error) { /* other receive is used */ }

	default event void NotifyCoordinates.notify(nmea_coordinates_t* coords) { }

	default event void NotifyTime.notify(time64_t now) { }

	// Provide module info string though deviceparameters
	PROGMEM const char m_gnss_mod_info_id[]  = "gnss_mod_info";

	task void sendModuleInfo() {
		char id[16+1];
		strcpy_P(id, m_gnss_mod_info_id);
		signal ModuleInfoParameter.value(id, DP_TYPE_STRING, &m_module_info, strlen(m_module_info));
	}

	command bool ModuleInfoParameter.matches(const char* identifier) {
		return 0 == strcmp_P(identifier, m_gnss_mod_info_id);
	}

	command error_t ModuleInfoParameter.get() { return post sendModuleInfo(); }

	command error_t ModuleInfoParameter.set(void* value, uint8_t length) { return FAIL; }

}
