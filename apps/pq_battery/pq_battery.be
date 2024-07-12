#######################################################################
# PowerQuartier batter UI & Simulator
#
#######################################################################
import persist
import webserver

var pq_battery = module('pq_battery')

class PqLogger
  var logLevel, name
  def init(level, name)
    self.logLevel = level
    self.name = name
  end

  def error(message)
    self.log(1, "ERR: "..message)
  end

  def info(message)
    self.log(2, "INF: "..message)
  end

  def warn(message)
    self.log(3, "WRN: "..message)
  end

  def debug(message)
    self.log(4, "DBG: "..message)
  end

  def log(level, message)
    if level <= self.logLevel
      print(self.name.." | "..message)
    end
  end
end

class PqBatteryUi
  var labelMeterNetLoadW, labelBatteryNetLoadW, labelArcSoc, arcSoc
  var battery
  def init(battery)
    self.battery = battery

    lv.start()
    import string

    self.labelBatteryNetLoadW = lv.label(lv.scr_act())
    self.labelBatteryNetLoadW.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN)
    self.labelBatteryNetLoadW.set_pos(170,200)
    self.labelBatteryNetLoadW.set_style_text_font(lv.montserrat_font(28), lv.PART_MAIN)
    # self.labelBatteryNetLoadW.set_text(string.format("%d W", battery.netLoadW))


    self.labelMeterNetLoadW = lv.label(lv.scr_act())
    self.labelMeterNetLoadW.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN)
    self.labelMeterNetLoadW.set_pos(170,240)
    self.labelMeterNetLoadW.set_style_text_font(lv.montserrat_font(28), lv.PART_MAIN)
    # self.labelMeterNetLoadW.set_text(string.format("%d W", battery.meter.netLoadW))
    
    self.labelArcSoc = lv.label(lv.scr_act())
    self.labelArcSoc.set_style_text_color(lv.color(0xFFFFFF), lv.PART_MAIN)
    self.labelArcSoc.set_style_text_font(lv.montserrat_font(28), lv.PART_MAIN)
    self.arcSoc = lv.arc(lv.scr_act())
    self.arcSoc.set_size(240, 240)
    self.arcSoc.set_rotation(135)
    self.arcSoc.set_bg_angles(0, 270)
    # self.arcSoc.set_value(battery.status["soc"])
    self.arcSoc.set_pos(120,120)
    
    self.arcSoc.add_event_cb(/->self.value_changed_event_cb(), lv.EVENT_VALUE_CHANGED, 0)
    # arcSoc.send_event(lv.EVENT_VALUE_CHANGED, self.labelArcSoc)

    tasmota.add_cron("*/1 * * * * *", / -> self.updateUi(), "every_1_s")

  end

  def value_changed_event_cb(obj, event)
    import string
    self.labelArcSoc.set_text(string.format("%d%%", self.arcSoc.get_value()))
    self.arcSoc.rotate_obj_to_angle(self.labelArcSoc, 25)
  end

  def updateUi()
    import string
    self.labelBatteryNetLoadW.set_text(string.format("%d W", self.battery.netLoadW))
    self.labelMeterNetLoadW.set_text(string.format("%d W", self.battery.meter.netLoadW))
    self.arcSoc.set_value(int(self.battery.status["soc"]))
    self.arcSoc.send_event(lv.EVENT_VALUE_CHANGED, self.labelArcSoc)
  end
end

def quantizeNowS(quantizer)
  var nowS = tasmota.rtc()["utc"]
  return nowS - (nowS % quantizer)
end

class PqMeter
  var importWh, exportWh, netLoadW
  var lastUpdateTimestampS
  var log

  def init()
    import persist
    self.log = PqLogger(4, "Meter")
    self.netLoadW = 0
    self.importWh = 0
    self.exportWh = 0
    self.lastUpdateTimestampS = tasmota.rtc()["local"]
    # tasmota.add_cron("*/15 * * * * *", / -> self.updateRegisters(), "every_15_s")
    # tasmota.add_cron("0 */15 * * * *", / -> self.sendMeasurements(), "every_15_m")

    tasmota.add_cron("*/1 * * * * *", / -> self.updateRegisters(), "every_1_s")
    tasmota.add_cron("0 */1 * * * *", / -> self.sendMeasurements(), "every_1_m")

  end

  def updateRegisters()
    var nowS = tasmota.rtc()["local"]
    var deltaTS = nowS - self.lastUpdateTimestampS
    self.lastUpdateTimestampS = nowS
    var deltaWorkWh = self.netLoadW * deltaTS / 3600.0 / 1000

    if (deltaWorkWh > 0)
      self.importWh += deltaWorkWh
    else
      if (deltaWorkWh < 0)
        self.exportWh += deltaWorkWh
      end
    end
  end

  def sendMeasurements()
    var nowQuantizedS = quantizeNowS(15 * 60)
    var tString = tasmota.strftime("%Y-%m-%dT%H:%M:%S", tasmota.rtc()["local"])
    self.log.info(tString)
    var measurement = {
      "timestamp": tString,
      "tags": {
        "muid": "e5ddaa76-a77f-4da4-acb3-407290e66907"
      },
      "fields": {
        "0100011D00FF": self.importWh,
        "0100021D00FF": self.exportWh
      }
    }
    self.log.info(measurement)
    self.importWh = 0
    self.exportWh = 0
  end

end

class PqBattery
  var config, status, schedule
  var netLoadW
  var lastSocUpdateTimestampS
  var meter
  var ui
  var log

  def init()
    import persist
    self.meter = PqMeter()
    self.log = PqLogger(4, "Battery")
    self.ui = PqBatteryUi(self)
    self.lastSocUpdateTimestampS = tasmota.rtc()["local"]
    self.netLoadW = 0
    if ! persist.has("batteryConfig")
      self.config = {
        "capacityKwh": 30,
        "maxChargeRateKw": 30,
        "maxDischargeRateKw": 30,
        "chemistry": "LiCoO"
      }
      persist.batteryConfig = self.config
      persist.save()
    else
      self.config = persist.batteryConfig
    end
    if ! persist.has("batteryStatus")
      self.status = {
        "soc": 50.0,
        "soh": 100.0
      }
      persist.batteryStatus = self.status
      persist.save()
    else
      self.status = persist.batteryStatus
    end
    if ! persist.has("batterySchedule")
      self.schedule = persist.batterySchedule
      persist.batterySchedule = self.schedule
      persist.save()
    else
      self.schedule = {}
      self.updateSchedule()
    end
    tasmota.add_cron("0 * * * * *", / -> self.tick(), "every_1_m")
    tasmota.add_cron("0 0 */14 * * *", / -> self.updateSchedule(), "every_24_h")
  end

  def updateSchedule()
    import persist
    if persist.has("email") && persist.has("password")
      # import powerquartier
      var pqClient = powerquartier.Client(persist.email, bytes().fromb64(persist.password).asstring())
      var cuid = "7d097ebd-ceae-4ef4-9c93-906b69110cc0"
      var uri = "/forecastmaker/community/" + cuid + "/forecast?interval=15m"
      var forecast = pqClient.get_uri(uri)

      var nowQuantizedS = quantizeNowS(15 * 60)
      
      # TODO: Remove this line - predates the schedule by 2 hours
      # nowQuantizedS -= 2 * 60 * 60

      var schedule = {}
      for i:0..(forecast["production"].size()-1)
        var netLoadW = (forecast["consumption"][i][1] + forecast["production"][i][1]) * 4
        var timestampS = nowQuantizedS + i * (15 * 60)

        # Clamp netLoadW to maxChargeRateKw and maxDischargeRateKw
          if netLoadW < -self.config["maxChargeRateKw"] * 1000
            netLoadW = -self.config["maxChargeRateKw"] * 1000
          end
          if netLoadW > self.config["maxDischargeRateKw"] * 1000
            netLoadW = self.config["maxDischargeRateKw"] * 1000
          end
        schedule[timestampS] = -netLoadW
      end
      self.schedule = schedule
      persist.batterySchedule = schedule
      persist.save()
    end
  end

  def updateNetLoad(netLoadW)
    self.netLoadW = netLoadW
    self.meter.netLoadW = self.netLoadW
  end

  def updateScheduledNetLoad()
    var nowQuantizedS = quantizeNowS(15 * 60)
    var tString = tasmota.strftime("%Y-%m-%dT%H:%M:%S", nowQuantizedS)
    self.log.debug("Updating for timestamp: "..nowQuantizedS.." / "..tString)
    var netLoadW = 0
    if self.schedule.has(nowQuantizedS)
      netLoadW = self.schedule[nowQuantizedS]
      self.log.debug("Found netLoad setpoint: "..netLoadW)
    else
      self.log.debug("No netLoad setpoint found.")
    end

    if self.status["soc"] >= 100
      if netLoadW > 0
        netLoadW = 0
      end
    end
    if self.status["soc"] <= 0
      if netLoadW < 0
        netLoadW = 0
      end
    end

    self.updateNetLoad(netLoadW)
  end

  def updateSoc()
    var nowS = tasmota.rtc()["local"]
    # Integrate linearly over time from last update
    var deltaTS = nowS - self.lastSocUpdateTimestampS
    self.lastSocUpdateTimestampS = nowS
    var deltaWorkWh = self.netLoadW * deltaTS / 3600.0 / 1000
    var deltaSoc = deltaWorkWh / self.config["capacityKwh"] * 100
    if deltaSoc != 0
      self.status["soc"] = self.status["soc"] + deltaSoc
    end

    self.log.debug("Current SoC "..self.status["soc"])
    self.log.debug("Delta SoC "..deltaSoc)
    self.log.debug("Delta TS "..deltaTS)
    self.log.debug("Delta Work Wh "..deltaWorkWh)

    if self.status["soc"] > 100
      self.status["soc"] = 100
      self.updateNetLoad(0)
    end
    if self.status["soc"] < 0
      self.status["soc"] = 0
      self.updateNetLoad(0)
    end
  end

  def tick()
    self.updateSoc()
    self.updateScheduledNetLoad()
  end
end
  
class PqBatteryUi
  import persist
  var config
  var status
  def init()
    if ! persist.has("batteryConfig")
      self.config = {
        "capacityKwh": 30,
        "maxChargeRateKw": 30,
        "maxDischargeRateKw": 30,
        "chemistry": "LiCoO"
      }
    else
      self.config = persist.batteryConfig
    end

  end
  
  def web_add_config_button()
    webserver.content_send("<p><form id=pq_battery action='pq_battery' style='display: block;' method='get'><button>Set up Battery Sim</button></form></p>")
  end

  def findInList(array, key, value)
    for item:array
        if item[key] == value
            return item
        end
    end
    return nil
  end
  
  #######################################################################
  # Display the complete page on `/pq_battery'
  #######################################################################
  
  def get_pq_battery()
    if !webserver.check_privileged_access() return nil end

      webserver.content_start("PowerQuartier Battery Simulator")           #- title of the web page -#
      webserver.content_send_style()                  #- send standard Tasmota styles -#
      webserver.content_send("<fieldset><style>.bdis{background:#888;}.bdis:hover{background:#888;}</style>")
      webserver.content_send(format("<legend><b title='PowerQuartier'>Battery Simulator</b></legend>"))
      webserver.content_send("<p><form id=pq_battery style='display: block;' action='/pq_battery' method='post'>")
      webserver.content_send(format("<table style='width:100%%'>"))
      webserver.content_send("<tr><td style='width:100px'><b>Capacity (kWh):</b></td>")
      webserver.content_send(format("<td style='width:300px'><input type='number' name='capacityKwh' value='%s'></td></tr>", self.config["capacityKwh"]))
      webserver.content_send("<tr><td style='width:100px'><b>Max discharge Rate (kW):</b></td>")
      webserver.content_send(format("<td style='width:300px'><input type='number' name='maxDischargeRateKw' value='%s'></td></tr>", self.config["maxDischargeRateKw"]))
      webserver.content_send("<tr><td style='width:100px'><b>Max charge Rate (kW):</b></td>")
      webserver.content_send(format("<td style='width:300px'><input type='number' name='maxChargeRateKw' value='%s'></td></tr>", self.config["maxChargeRateKw"]))
      webserver.content_send("</table><hr>")
      webserver.content_send("<button name='store_battery' class='button bgrn'>Save</button>")
      webserver.content_send("</form></p>")
      webserver.content_send("<p></p></fieldset><p></p>")
      webserver.content_button(webserver.BUTTON_CONFIGURATION)
      webserver.content_stop()
    end
    
    def post_pq_battery()
      if !webserver.check_privileged_access() return nil end      
      try
        if webserver.has_arg("store_battery")
          # read arguments
          if (webserver.arg("capacityKwh") != nil)
            self.config["capacityKwh"] = webserver.arg("capacityKwh")
          end
          if (webserver.arg("maxDischargeRateKw") != nil)
            self.config["maxDischargeRateKw"] = webserver.arg("maxDischargeRateKw")
          end
          if (webserver.arg("maxChargeRateKw") != nil)
            self.config["maxChargeRateKw"] = webserver.arg("maxChargeRateKw")
          end
          persist.batteryConfig = self.config
          persist.save()
          webserver.redirect("/cn?")
        end
      except .. as e,m
        print(format("BRY: Exception> '%s' - %s", e, m))
        #- display error page -#
        webserver.content_start("Parameter error")           #- title of the web page -#
        webserver.content_send_style()                  #- send standard Tasmota styles -#
        webserver.content_send(format("<p style='width:340px;'><b>Exception:</b><br>'%s'<br>%s</p>", e, m))
        webserver.content_button(webserver.BUTTON_CONFIGURATION) #- button back to management page -#
        webserver.content_stop()                        #- end of web page -#
      end
    end
    
    
    #- ---------------------------------------------------------------------- -#
    # respond to web_add_handler() event to register web listeners
    #- ---------------------------------------------------------------------- -#
    #- this is called at Tasmota start-up, as soon as Wifi/Eth is up and web server running -#
      
    def web_add_handler()
      #- we need to register a closure, not just a function, that captures the current instance -#
      webserver.on("/pq_battery", / -> self.get_pq_battery(), webserver.HTTP_GET)
      webserver.on("/pq_battery", / -> self.post_pq_battery(), webserver.HTTP_POST)
    end
end  

pq_battery.PqMeter=PqMeter
pq_battery.PqBattery=PqBattery
pq_battery.PqBatteryUi=PqBatteryUi


#- create and register driver in Tasmota -#
if tasmota
  var PqBatteryUi_instance = pq_battery.PqBatteryUi()
  tasmota.add_driver(PqBatteryUi_instance)
  ## can be removed if put in 'autoexec.bat'
  PqBatteryUi_instance.web_add_handler()
end

return pq_battery

#- For debugging purposes, you can manually call the following to register the web handler -#
#- as it is automatically called only if the instance was registered at startup, for example
#- in `autoexec.be` -#
#-

web_page_demo_instance.web_add_handler()

-#