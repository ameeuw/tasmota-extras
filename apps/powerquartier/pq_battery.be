#######################################################################
# PowerQuartier batter UI & Simulator
#
#######################################################################
import persist
import webserver

var pq_battery = module('pq_battery')

def quantizeNowS(quantizer)
  var nowS = tasmota.rtc()["local"]
  return nowS - (nowS % quantizer)
end
  

class PqMeter
  var importWh
  var exportWh
  var netLoadW
  var lastUpdateTimestampS

  def init()
    self.lastUpdateTimestampS = tasmota.rtc()["local"]
    self.netLoadW = 0
    self.importWh = 0
    self.exportWh = 0
    tasmota.add_cron("* */1 * * * *", def () self.update() end, "meter_update")
    tasmota.add_cron("* */15 * * * *", def () self.sendMeasurements() end, "meter_send")
  end

  def update()
    var nowS = tasmota.rtc()["local"]
    var deltaTS = nowS - self.lastUpdateTimestampS
    self.lastUpdateTimestampS = nowS
    var deltaWorkWh = self.netLoadW * deltaTS / 3600.0 / 1000

    if (deltaWorkWh > 0)
      self.exportWh += deltaWorkWh
    else
      self.importWh -= deltaWorkWh
    end
  end

  def sendMeasurements()
    var nowQuantizedS = quantizeNowS(15 * 60)
    var tString = tasmota.strftime("%Y-%m-%dT%H:%M:%S", nowQuantizedS)
    print(tString)
    var measurement = {
      "timestamp": tString,
      "tags": {
        "muid": "tbd"
      },
      fields: {
        "0100011D00FF": self.importWh,
        "0100021D00FF": self.exportWh
      }
    }
    print(measurement)
    self.importWh = 0
    self.exportWh = 0
  end

end

import persist
class PqBattery
  var config, status, schedule
  var netLoadW
  var lastSocUpdateTimestampS
  var meter

  def init()
    self.meter = PqMeter()
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
    tasmota.add_cron("* */5 * * * *", def () self.tick() end, "every_1_m")
    tasmota.add_cron("* * */0 * * *", def () self.updateSchedule() end, "every_24_h")
  end

  def updateSchedule()
    if persist.has("email") && persist.has("password")
      # import powerquartier
      var pqClient = powerquartier.Client(persist.email, bytes().fromb64(persist.password).asstring())
      var cuid = "693c029b-a7fb-417b-9d17-a049f1a51ce7"
      var uri = "/forecastmaker/community/" + cuid + "/forecast"
      var forecast = pqClient.get_uri(uri)

      var nowQuantizedS = quantizeNowS(15 * 60)
      
      # TODO: Remove this line - predates the schedule by 2 hours
      nowQuantizedS -= 2 * 60 * 60

      var schedule = {}
      for i:0..(forecast["production"].size()-1)
        var netLoadW = (forecast["consumption"][i][1] + forecast["production"][i][1]) * 4
        var timestampS = nowQuantizedS + (i + 1) * dtS

        # Clamp netLoadW to maxChargeRateKw and maxDischargeRateKw
        if netLoadW > self.config["maxChargeRateKw"] * 1000
          netLoadW = self.config["maxChargeRateKw"] * 1000
        end
        if netLoadW < -self.config["maxDischargeRateKw"] * 1000
          netLoadW = -self.config["maxDischargeRateKw"] * 1000
        end
        schedule[timestampS] = netLoadW
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
    print(tString)
    var netLoadW = 0
    if self.schedule.has(nowQuantizedS)
      print("Found netLoad setpoint: ")
      netLoadW = self.schedule[nowQuantizedS]
      print(netLoadW)
    else
      print("No netLoad setpoint found.")
    end
    self.updateNetLoad(netLoadW)
  end

  def updateSoc()
    var nowS = tasmota.rtc()["local"]
    var deltaTS = nowS - self.lastSocUpdateTimestampS
    self.lastSocUpdateTimestampS = nowS
    var deltaWorkWh = self.netLoadW * deltaTS / 3600.0 / 1000
    self.status["soc"] -= deltaWorkWh / self.config["capacityKwh"] * 100

    print("Update SoC")
    print(deltaTS)
    print(self.netLoadW)
    print(self.status["soc"])

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
    print("Battery: tick()")
    self.updateSoc()
    self.updateScheduledNetLoad()
  end
end
  
class PqBatteryUi
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