#include <Keypad.h>

// housekeeping / readability stuff
const int MAX_ADC = 1023;

// polling management
const unsigned long SEND_EVERY = 200;
const unsigned long RECEIVE_EVERY = 200;
unsigned long last_sent_at;
unsigned long now;
unsigned long last_received_at = 0;

// pin assignments
// 2-7 are used for keypad. 
// keep 8 open in case we hook up the last row of keys.
const byte AUTOPILOT_MODE_PIN = A0;
const byte       THROTTLE_PIN = A1;
const byte          STAGE_PIN = A2;
const byte         BUZZER_PIN =  9;
const byte SWITCHES_CLOCK_PIN = 10;
const byte SWITCHES_LATCH_PIN = 11;
const byte  SWITCHES_DATA_PIN = 12;
const byte           LINK_PIN = 13;

// read in from shift register
byte switch_settings = 203;

// bit assignments in the switch_settings byte
const byte AUTOPILOT_ENABLE_BIT = 1;
const byte       RCS_ENABLE_BIT = 2;
const byte       SAS_ENABLE_BIT = 3;
const byte    LIGHTS_ENABLE_BIT = 4;
const byte  THROTTLE_ENABLE_BIT = 5;
const byte    BRAKES_ENABLE_BIT = 6;
const byte      GEAR_ENABLE_BIT = 7;

bool autopilot_enabled;
bool throttle_enabled;

// keypad setup
const char NO_ACTION = '-';
const byte KEY_ROWS = 3;
const byte KEY_COLS = 3;
char keys[KEY_ROWS][KEY_COLS] = {
  {'1','2','3'},
  {'4','5','6'},
  {'7','8','9'}
};
byte rowPins[KEY_ROWS] = {3, 8, 7};
byte colPins[KEY_COLS] = {4, 2, 6};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, KEY_ROWS, KEY_COLS);
char current_action_group;

String last_sent_message = "";

bool doStage = false;
bool stageCurrent = false;
bool stagePrevious = false;

void setup(){
  Serial.begin(9600);
  last_sent_at = 0;
  current_action_group = NO_ACTION;
  pinMode(LINK_PIN, OUTPUT);
  pinMode(SWITCHES_LATCH_PIN, OUTPUT);
  pinMode(SWITCHES_CLOCK_PIN, OUTPUT);
  pinMode(SWITCHES_DATA_PIN, INPUT);
}

void loop(){
  char maybe_action_group = keypad.getKey();
  if (maybe_action_group != NO_KEY){
    current_action_group = maybe_action_group;
  }

  // require a LOW -> HIGH state change to trigger staging.
  stageCurrent = digitalRead(STAGE_PIN) == HIGH ? true : false;
  if (stageCurrent && !stagePrevious) {
    doStage = true;
  } else {
    doStage = false;
  }
  stagePrevious = stageCurrent;

  now = millis();
  if (now - last_sent_at >= SEND_EVERY) {
    // read switch settings from shift register
    // https://www.arduino.cc/en/Tutorial/ShftIn21
    digitalWrite(SWITCHES_LATCH_PIN, 1);
    delayMicroseconds(20);
    digitalWrite(SWITCHES_LATCH_PIN, 0);
    switch_settings = shiftIn(SWITCHES_DATA_PIN, SWITCHES_CLOCK_PIN, MSBFIRST);
  
    String autopilot_mode;
    autopilot_enabled = bitRead(switch_settings, AUTOPILOT_ENABLE_BIT);
    if (autopilot_enabled) {
      // https://learn.sparkfun.com/tutorials/rotary-switch-potentiometer-hookup-guide#project-i-10-item-selector
      uint16_t autopilot_mode_raw = analogRead(AUTOPILOT_MODE_PIN);
      // should this be '9' or '10'?
      // 10 steps, 0-9. +51 to hit middle of each bucket.
      // 10 steps across range 0-1023 = 102.3 per bucket. 102 / 2 = 51
      autopilot_mode = String((autopilot_mode_raw + 51) * 9 / MAX_ADC);
    } else {
      autopilot_mode = '-';
    }

    String throttle;
    throttle_enabled = bitRead(switch_settings, THROTTLE_ENABLE_BIT);
    if (throttle_enabled) {
      uint16_t throttle_raw = analogRead(THROTTLE_PIN);
      throttle = String((throttle_raw * 99L) / 1023);
      if (throttle.length() == 1) {
        throttle = "0" + throttle;
      }
    } else {
      throttle = "00";
    }

    // flags is a bitmask for various boolean values
    // staging, action groups, and switch settings
    unsigned long flags = 0;

    bitWrite(flags, 0, int(doStage));
    if (doStage) {
      tone(BUZZER_PIN, 200, 50);
      doStage = false;
    }
    
    // order of bits in `switch_settings` to write out in `flags`
    // this must match the order that ruby expects
    byte flag_mapping[] = {
      0, // bit 0 is staging, set above.
      SAS_ENABLE_BIT,
      RCS_ENABLE_BIT,
      LIGHTS_ENABLE_BIT,
      GEAR_ENABLE_BIT,
      BRAKES_ENABLE_BIT
    };
    
    for(byte i = 1; i < sizeof(flag_mapping); i++) {
      bitWrite(flags, i, bitRead(switch_settings, flag_mapping[i]));
    }
    
    if (current_action_group != NO_ACTION) {
      bitSet(flags, sizeof(flag_mapping) + String(current_action_group).toInt() - 1);
      tone(BUZZER_PIN, 1600, 50);
      current_action_group = NO_ACTION;
    }

    String current_message = throttle + autopilot_mode + String(flags);
    if (current_message != last_sent_message) {
      Serial.println(current_message);
      last_sent_message = current_message;
      last_sent_at = now; // TODO not tested. last_sent_at should maybe be last_checked_at (checked control state)
    }

    updateLinkState();
  }
}

void updateLinkState() {
  while(Serial.available()) {
    Serial.read();
    last_received_at = millis();
  }

  int link_active;
  if (millis() - last_received_at < RECEIVE_EVERY) {
    link_active = HIGH;
  } else {
    link_active = LOW;
  }
  digitalWrite(LINK_PIN, link_active);
}
