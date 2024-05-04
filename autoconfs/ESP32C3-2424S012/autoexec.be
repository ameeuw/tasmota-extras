import json
import mqtt
import string
import math

lv.start()


hres = lv.get_hor_res()       # should be 240
vres = lv.get_ver_res()       # should be 240

scr = lv.scr_act()            # default screen object
f20 = lv.montserrat_font(20)  # load embedded Montserrat 20


# --- FLOW & IN-OUT-TEMPS --- #

meter_flow = lv.meter(scr)
meter_flow.set_size(240, 240)
meter_flow.set_pos(0, 0)
meter_flow.remove_style(nil, lv.PART_INDICATOR)


scale = meter_flow.add_scale()

meter_flow.set_scale_ticks(scale, 11, 2, 10, lv.color(0xDDDDDD))
meter_flow.set_scale_major_ticks(scale, 2, 5, -5, lv.color(0xEEEEEE), 0)
meter_flow.set_scale_range(scale, 0, 60, 270, 90)

label_meter_flow = lv.label(scr)
label_meter_flow.set_style_text_color(lv.color(0x000000), lv.PART_MAIN | lv.STATE_DEFAULT)
label_meter_flow.set_width(80)
label_meter_flow.set_pos(130,180)
label_meter_flow.set_text("0")

label_meter_flow_in = lv.label(scr)
label_meter_flow_in.set_style_text_color(lv.color(0x000000), lv.PART_MAIN | lv.STATE_DEFAULT)
label_meter_flow_in.set_width(80)
label_meter_flow_in.set_pos(130,195)
label_meter_flow_in.set_text("0°C")

label_meter_flow_out = lv.label(scr)
label_meter_flow_out.set_style_text_color(lv.color(0x000000), lv.PART_MAIN | lv.STATE_DEFAULT)
label_meter_flow_out.set_width(80)
label_meter_flow_out.set_pos(130,210)
label_meter_flow_out.set_text("0°C")

meter_flow_in_indicator = meter_flow.add_arc(scale, 10, lv.color(0x0000FF), -10)
meter_flow_out_indicator = meter_flow.add_arc(scale, 10, lv.color(0xFF0000), -20)
meter_flow_indicator = meter_flow.add_arc(scale, 10, lv.color(0x00FF00), -30)

meter_flow.set_indicator_end_value(meter_flow_in_indicator, 32)
meter_flow.set_indicator_end_value(meter_flow_indicator, 60)
meter_flow.set_indicator_end_value(meter_flow_out_indicator, 35)

# --- Update values --- #

def sensor_callback(topic, idx, payload_s)
    var payload = json.load(payload_s)

    print(string.format("Flow count: %d",payload["COUNTER"]["C1"]))
    meter_flow.set_indicator_end_value(meter_flow_indicator, int(payload["COUNTER"]["C1"]/10))
    label_meter_flow.set_text(string.format("%d",int(payload["COUNTER"]["C1"])))

    print(string.format("Flow-IN temperature: %.1f°C",payload["ANALOG"]["Temperature1"]))
    meter_flow.set_indicator_end_value(meter_flow_in_indicator, int(payload["ANALOG"]["Temperature1"]))
    label_meter_flow_in.set_text(string.format("%.1f°C",payload["ANALOG"]["Temperature1"]))

    print(string.format("Flow-OUT temperature: %.1f°C",payload["ANALOG"]["Temperature2"]))
    meter_flow.set_indicator_end_value(meter_flow_out_indicator, int(payload["ANALOG"]["Temperature2"]))
    label_meter_flow_out.set_text(string.format("%.1f°C",payload["ANALOG"]["Temperature2"]))

    return true
end

mqtt.subscribe("tele/COOLBOX/SENSOR", sensor_callback)
