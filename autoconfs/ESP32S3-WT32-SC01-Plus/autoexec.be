import json
import string
import mqtt
import math

#- start LVGL and init environment -#
lv.start()

hres = lv.get_hor_res()       # should be 320
vres = lv.get_ver_res()       # should be 240

scr = lv.scr_act()            # default screen object
f20 = lv.montserrat_font(20)  # load embedded Montserrat 20

#- Upper state line -#
stat_line = lv.label(scr)
if f20 != nil stat_line.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
stat_line.set_long_mode(lv.LABEL_LONG_SCROLL)                                        # auto scrolling if text does not fit
stat_line.set_width(hres)
stat_line.set_align(lv.TEXT_ALIGN_LEFT)                                              # align text left
stat_line.set_style_bg_color(lv.color(0xD00000), lv.PART_MAIN | lv.STATE_DEFAULT)    # background #000088
stat_line.set_style_bg_opa(lv.OPA_COVER, lv.PART_MAIN | lv.STATE_DEFAULT)            # 100% background opacity
stat_line.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
stat_line.set_text("Ludwig")
stat_line.refr_size()                                                                # new in LVGL8
stat_line.refr_pos()                                                                 # new in LVGL8

#- display wifi strength indicator icon (for professionals ;) -#
wifi_icon = lv_wifi_arcs_icon(stat_line)    # the widget takes care of positioning and driver stuff
clock_icon = lv_clock_icon(stat_line)

row_y = 100

# --- TEC1 --- #

led_tec1 = lv.led(scr)
led_tec1.set_pos(10,row_y)

switch_tec1 = lv.switch(scr)
switch_tec1.set_pos(40,row_y)

label_tec1 = lv.label(scr)
if f20 != nil label_tec1.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
label_tec1.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
label_tec1.set_pos(10,row_y-60)
label_tec1.set_text("TEC1")

label_tec1_amps = lv.label(scr)
if f20 != nil label_tec1_amps.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
label_tec1_amps.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
label_tec1_amps.set_pos(10,row_y-30)
label_tec1_amps.set_text("0 mA")

# --- TEC2 --- #

led_tec2 = lv.led(scr)
led_tec2.set_pos(110,row_y)

switch_tec2 = lv.switch(scr)
switch_tec2.set_pos(140,row_y)

label_tec2 = lv.label(scr)
if f20 != nil label_tec2.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
label_tec2.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
label_tec2.set_pos(110,row_y-60)
label_tec2.set_text("TEC2")

label_tec2_amps = lv.label(scr)
if f20 != nil label_tec2_amps.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
label_tec2_amps.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
label_tec2_amps.set_pos(110,row_y-30)
label_tec2_amps.set_text("0 mA")

# --- CYCLE --- #

led_cycle = lv.led(scr)
led_cycle.set_pos(210,row_y)

switch_cycle = lv.switch(scr)
switch_cycle.set_pos(240,row_y)

label_cycle = lv.label(scr)
if f20 != nil label_cycle.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
label_cycle.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
label_cycle.set_pos(210,row_y-60)
label_cycle.set_text("CYCLE")

label_cycle_temp = lv.label(scr)
if f20 != nil label_cycle_temp.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
label_cycle_temp.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
label_cycle_temp.set_pos(210,row_y-30)
label_cycle_temp.set_text("0 °C")

# --- RADIATOR --- #

led_radiator = lv.led(scr)
led_radiator.set_pos(310,row_y)

switch_radiator = lv.switch(scr)
switch_radiator.set_pos(340,row_y)

label_radiator = lv.label(scr)
if f20 != nil label_radiator.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
label_radiator.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
label_radiator.set_pos(310,row_y-60)
label_radiator.set_text("RADIATOR")

label_radiatior_temp = lv.label(scr)
if f20 != nil label_radiatior_temp.set_style_text_font(f20, lv.PART_MAIN | lv.STATE_DEFAULT) end
label_radiatior_temp.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
label_radiatior_temp.set_pos(310,row_y-30)
label_radiatior_temp.set_text("0 °C")

# --- Water --- #

meter_water_temp = lv.meter(scr)
meter_water_temp.set_pos(10, 150)
meter_water_temp.set_size(150, 150)
scale = meter_water_temp.add_scale()
meter_water_temp.set_scale_ticks(scale, 41,2,10, lv.color(0xDDDDDD))
meter_water_temp.set_scale_major_ticks(scale, 8, 4, 15, lv.color_black(), 10)

indic = meter_water_temp.add_arc(scale, 3, lv.color(0x0000FF), 0)
meter_water_temp.set_indicator_start_value(indic, 0)
meter_water_temp.set_indicator_end_value(indic, 20)
indic = meter_water_temp.add_scale_lines(scale, lv.color(0x0000FF), lv.color(0x0000FF), false, 0)
meter_water_temp.set_indicator_start_value(indic, 0)
meter_water_temp.set_indicator_end_value(indic, 20)

indic = meter_water_temp.add_arc(scale, 3, lv.color(0xFF0000), 0)
meter_water_temp.set_indicator_start_value(indic, 80)
meter_water_temp.set_indicator_end_value(indic, 100)
indic = meter_water_temp.add_scale_lines(scale, lv.color(0xFF0000), lv.color(0xFF0000), false, 0)
meter_water_temp.set_indicator_start_value(indic, 80)
meter_water_temp.set_indicator_end_value(indic, 100)

indic_water_temp = meter_water_temp.add_needle_line(scale, 4, lv.color(0x555555), -10)

label_meter_water_temp = lv.label(scr)
label_meter_water_temp.set_style_text_color(lv.color(0x000000), lv.PART_MAIN | lv.STATE_DEFAULT)
label_meter_water_temp.set_width(80)
label_meter_water_temp.set_pos(65,270)
label_meter_water_temp.set_text("0°C")

meter_water_temp.set_indicator_value(indic_water_temp, 60)

# --- Air --- #

meter_air_temp = lv.meter(scr)
meter_air_temp.set_pos(165, 150)
meter_air_temp.set_size(150, 150)
scale = meter_air_temp.add_scale()
meter_air_temp.set_scale_ticks(scale, 41,2,10, lv.color(0xDDDDDD))
meter_air_temp.set_scale_major_ticks(scale, 8, 4, 15, lv.color_black(), 10)

indic = meter_air_temp.add_arc(scale, 3, lv.color(0x0000FF), 0)
meter_air_temp.set_indicator_start_value(indic, 0)
meter_air_temp.set_indicator_end_value(indic, 20)
indic = meter_air_temp.add_scale_lines(scale, lv.color(0x0000FF), lv.color(0x0000FF), false, 0)
meter_air_temp.set_indicator_start_value(indic, 0)
meter_air_temp.set_indicator_end_value(indic, 20)


indic = meter_air_temp.add_arc(scale, 3, lv.color(0xFF0000), 0)
meter_air_temp.set_indicator_start_value(indic, 80)
meter_air_temp.set_indicator_end_value(indic, 100)
indic = meter_air_temp.add_scale_lines(scale, lv.color(0xFF0000), lv.color(0xFF0000), false, 0)
meter_air_temp.set_indicator_start_value(indic, 80)
meter_air_temp.set_indicator_end_value(indic, 100)

indic_air_temp = meter_air_temp.add_needle_line(scale, 4, lv.color(0x555555), -10)

label_meter_air_temp = lv.label(scr)
label_meter_air_temp.set_style_text_color(lv.color(0x000000), lv.PART_MAIN | lv.STATE_DEFAULT)
label_meter_air_temp.set_width(80)
label_meter_air_temp.set_pos(220,270)
label_meter_air_temp.set_text("0°C")


meter_air_temp.set_indicator_value(indic_air_temp, 60)


# --- FLOW & IN-OUT-TEMPS --- #

meter_flow = lv.meter(scr)
meter_flow.set_pos(325, 150)
meter_flow.set_size(150, 150)
meter_flow.remove_style(nil, lv.PART_INDICATOR)


scale = meter_flow.add_scale()

meter_flow.set_scale_ticks(scale, 11, 2, 10, lv.color(0xDDDDDD))
meter_flow.set_scale_major_ticks(scale, 2, 5, -5, lv.color(0xEEEEEE), 0)
meter_flow.set_scale_range(scale, 0, 60, 270, 90)

label_meter_flow_in = lv.label(scr)
label_meter_flow_in.set_style_text_color(lv.color(0x000000), lv.PART_MAIN | lv.STATE_DEFAULT)
label_meter_flow_in.set_width(80)
label_meter_flow_in.set_pos(405,250)
label_meter_flow_in.set_text("0°C")

label_meter_flow_out = lv.label(scr)
label_meter_flow_out.set_style_text_color(lv.color(0x000000), lv.PART_MAIN | lv.STATE_DEFAULT)
label_meter_flow_out.set_width(80)
label_meter_flow_out.set_pos(405,265)
label_meter_flow_out.set_text("0°C")

label_meter_flow = lv.label(scr)
label_meter_flow.set_style_text_color(lv.color(0x000000), lv.PART_MAIN | lv.STATE_DEFAULT)
label_meter_flow.set_width(80)
label_meter_flow.set_pos(405,235)
label_meter_flow.set_text("0")

meter_flow_in_indicator = meter_flow.add_arc(scale, 10, lv.color(0x0000FF), -10)
meter_flow_out_indicator = meter_flow.add_arc(scale, 10, lv.color(0xFF0000), -20)
meter_flow_indicator = meter_flow.add_arc(scale, 10, lv.color(0x00FF00), -30)

meter_flow.set_indicator_end_value(meter_flow_in_indicator, 32)
meter_flow.set_indicator_end_value(meter_flow_indicator, 60)
meter_flow.set_indicator_end_value(meter_flow_out_indicator, 35)


# --- Callbacks --- #

def switch_flipped_cb(obj, event)
    var switch = "Unknown"
    var state = obj.get_state() == 3 ? "ON" : "OFF"
    if obj == switch_tec1
        switch = "TEC1"
        mqtt.publish("cmnd/COOLBOX/power3", state)

    elif  obj == switch_tec2
        switch = "TEC2"
        mqtt.publish("cmnd/COOLBOX/power4", state)

    elif  obj == switch_cycle
        switch = "CYCLE"
        mqtt.publish("cmnd/COOLBOX/power2", state)

    elif  obj == switch_radiator
        switch = "RADIATOR"
        mqtt.publish("cmnd/COOLBOX/power1", state)
    end

    mqtt.publish("cmnd/COOLBOX/state", "")
    print(switch, "switch flipped to ", obj.get_state())
end

switch_tec1.add_event_cb(switch_flipped_cb, lv.EVENT_VALUE_CHANGED, 0)
switch_tec2.add_event_cb(switch_flipped_cb, lv.EVENT_VALUE_CHANGED, 0)
switch_cycle.add_event_cb(switch_flipped_cb, lv.EVENT_VALUE_CHANGED, 0)
switch_radiator.add_event_cb(switch_flipped_cb, lv.EVENT_VALUE_CHANGED, 0)


# --- Update values --- #

def sensor_callback(topic, idx, payload_s)
    var payload = json.load(payload_s)
    
    print(string.format("Air temperature: %.1f°C",payload["AM2301"]["Temperature"]))
    meter_air_temp.set_indicator_value(indic_air_temp, int(payload["AM2301"]["Temperature"]))
    label_meter_air_temp.set_text(string.format("%.1f°C",payload["AM2301"]["Temperature"]))

    print(string.format("Water temperature: %.1f°C",payload["DS18B20"]["Temperature"]))
    meter_water_temp.set_indicator_value(indic_water_temp, int(payload["DS18B20"]["Temperature"]))
    label_meter_water_temp.set_text(string.format("%.1f°C",payload["DS18B20"]["Temperature"]))

    print(string.format("Flow-IN temperature: %.1f°C",payload["ANALOG"]["Temperature1"]))
    meter_flow.set_indicator_end_value(meter_flow_in_indicator, int(payload["ANALOG"]["Temperature1"]))
    label_meter_flow_in.set_text(string.format("%.1f°C",payload["ANALOG"]["Temperature1"]))

    print(string.format("Flow-OUT temperature: %.1f°C",payload["ANALOG"]["Temperature2"]))
    meter_flow.set_indicator_end_value(meter_flow_out_indicator, int(payload["ANALOG"]["Temperature2"]))
    label_meter_flow_out.set_text(string.format("%.1f°C",payload["ANALOG"]["Temperature2"]))

    print(string.format("TEC1 current: %d mA",payload["ANALOG"]["Range3"]))
    label_tec1_amps.set_text(string.format("%d mA",payload["ANALOG"]["Range3"]))

    print(string.format("TEC2 current: %d mA",payload["ANALOG"]["Range4"]))
    label_tec2_amps.set_text(string.format("%d mA",payload["ANALOG"]["Range4"]))

    print(string.format("Flow count: %d",payload["COUNTER"]["C1"]))
    meter_flow.set_indicator_end_value(meter_flow_indicator, int(payload["COUNTER"]["C1"]/10))
    label_meter_flow.set_text(string.format("%d",int(payload["COUNTER"]["C1"])))

    return true
end

mqtt.subscribe("tele/COOLBOX/SENSOR", sensor_callback)

def status_callback(topic, idx, payload_s)
    var payload = json.load(payload_s)
    if payload.contains("POWER1")
        if (payload["POWER1"] == "ON")
            led_radiator.on()
        else
            led_radiator.off()
        end
    end
    if payload.contains("POWER2")
        if (payload["POWER2"] == "ON")
            led_cycle.on()
        else
            led_cycle.off()
        end
    end
    if payload.contains("POWER3")
        if (payload["POWER3"] == "ON")
            led_tec1.on()
        else
            led_tec1.off()
        end
    end

    if payload.contains("POWER4")
        if (payload["POWER4"] == "ON")
            led_tec2.on()
        else
            led_tec2.off()
        end
    end
end

mqtt.subscribe("stat/COOLBOX/RESULT", status_callback)

mqtt.publish("cmnd/COOLBOX/state", "")