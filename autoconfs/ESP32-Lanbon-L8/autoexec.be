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
stat_line.set_style_bg_color(lv.color(0xC3433D), lv.PART_MAIN | lv.STATE_DEFAULT)    # background #C3433D (Tasmota Red)
stat_line.set_style_bg_opa(lv.OPA_COVER, lv.PART_MAIN | lv.STATE_DEFAULT)            # 100% background opacity
stat_line.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN | lv.STATE_DEFAULT)  # text color #FFFFFF
stat_line.set_text("L8")
stat_line.refr_size()                                                                # new in LVGL8
stat_line.refr_pos()                                                                 # new in LVGL8

#- display wifi strength indicator icon (for professionals ;) -#
wifi_icon = lv_wifi_arcs_icon(stat_line)    # the widget takes care of positioning and driver stuff
clock_icon = lv_clock_icon(stat_line)

row_y = 50

var buttons = []         # relay buttons are added to this list to match with Tasmota relays


# --- Styles --- #


btn_style = lv.style()
btn_style.set_radius(10)                        # radius of rounded corners
btn_style.set_bg_opa(lv.OPA_COVER)              # 100% background opacity
if f20 != nil btn_style.set_text_font(f20) end  # set font to Montserrat 20
btn_style.set_bg_color(lv.color(0x1fa3ec))      # background color #1FA3EC (Tasmota Blue)
btn_style.set_border_color(lv.color(0x0000FF))  # border color #0000FF
btn_style.set_text_color(lv.color(0xFFFFFF))    # text color white #FFFFFF

btn_style_2 = lv.style()
btn_style_2.set_radius(10)                        # radius of rounded corners
btn_style_2.set_bg_opa(lv.OPA_COVER)              # 100% background opacity
if f20 != nil btn_style_2.set_text_font(f20) end  # set font to Montserrat 20
btn_style_2.set_bg_color(lv.color(0x6bbf70))      # background #6BBF70 color (Tasmota Green)
btn_style_2.set_border_color(lv.color(0x0000FF))  # border color #0000FF
btn_style_2.set_text_color(lv.color(0xFFFFFF))    # text color white #FFFFFF


#- simple function to find the index of an element in a list -#
def findinlist(l, x)
    for i:0..size(l)-1
      if l[i][0] == x
        return l[i]
      end
    end
  end

#- callback function when a button is pressed -#
#- checks if the button is in the list, and react to EVENT_VALUE_CHANGED event -#
def btn_event_cb(obj, event)
    var buttonChannel = findinlist(buttons, obj)
    if buttonChannel != nil # && event == lv.EVENT_VALUE_CHANGED
        var val = buttonChannel[0].get_state() < 3
        tasmota.set_power(buttonChannel[1], !val)
    end
end

# --- Relays --- #

def create_button_relay(label, channel)
    var button, button_label
    button = lv.btn(scr)                                             # create button with main screen as parent
    button.add_flag(lv.OBJ_FLAG_CHECKABLE)                           # create toggle
    button.set_pos(20,row_y)                                         # position of button
    button.set_size(200, 40)                                         # size of button
    button.add_style(btn_style, lv.PART_MAIN | lv.STATE_DEFAULT)     # style of button
    button.add_style(btn_style_2, lv.PART_MAIN | lv.STATE_CHECKED)   # add checked button style
    button_label = lv.label(button)                                  # create a label as sub-object
    button_label.set_text(label)                                        # set label text
    button_label.center()
    button.add_event_cb(btn_event_cb, lv.EVENT_VALUE_CHANGED, 0)
    return [button, channel]
end

def update_buttons()                                      # get a list of booleans with status of each relay
    for buttonChannel:buttons
        var power_state = tasmota.get_power(buttonChannel[1])
        var state = buttonChannel[0].get_state()
        if (power_state)
            buttonChannel[0].clear_state(2)
            buttonChannel[0].add_state(3)
        else
            buttonChannel[0].clear_state(3)
            buttonChannel[0].add_state(2)
        end
    end
end

#- update every 500ms -#
def update_buttons_loop()
    update_buttons()
    tasmota.set_timer(500, update_buttons_loop)
end
update_buttons_loop()  # start
  

buttons.push(create_button_relay("Relay 1", 0))
buttons[-1][0].set_y(row_y)
buttons.push(create_button_relay("Relay 2", 1))
buttons[-1][0].set_y(row_y * 2)
buttons.push(create_button_relay("Relay 3", 2))
buttons[-1][0].set_y(row_y * 3)
buttons.push(create_button_relay("Ambient", 3))
buttons[-1][0].set_y(row_y * 4)
buttons.push(create_button_relay("Screen", 4))
buttons[-1][0].set_y(row_y * 5)
