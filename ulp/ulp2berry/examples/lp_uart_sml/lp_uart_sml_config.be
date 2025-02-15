#######################################################################
# LP UART SML Config UI
#
#######################################################################
import webserver

var lp_uart_sml_config = module('lp_uart_sml_config')
  
class lp_uart_sml_config_class
  def init()
  end
  
  def web_add_config_button()
    webserver.content_send("<p><form id=lp_uart_sml action='lp_uart_sml' style='display: block;' method='get'><button>Configure LP UART SML</button></form></p>")
  end
  
  #######################################################################
  # Display the complete page on `/lp_uart_sml'
  #######################################################################
  
  def get_lp_uart_sml()
    if !webserver.check_privileged_access() return nil end
  
      webserver.content_start("LP UART SML Config")           #- title of the web page -#
      webserver.content_send_style()                  #- send standard Tasmota styles -#
      webserver.content_send("<style>label{display:block;}</style>")
        import json
        webserver.content_send(format("<legend><b title='PowerQuartier'>Accounts</b></legend>"))
        webserver.content_send("<p><form id=lp_uart_sml style='display: block;' action='/lp_uart_sml' method='post'>")
        webserver.content_send(format("<table style='width:100%%'>"))
        
        var obis_configs = tasmota.cmd('get_obis_configs')
        if (obis_configs)
          webserver.content_send("<th>OBIS</th><th>Unit</th><th>Scaler</th>")
          for obis_config:obis_configs
            webserver.content_send(
              format("<tr><td>%s</td><td>%i</td><td>%i</td></tr>", 
              obis_config["obis"], 
              obis_config["unit"], 
              obis_config["scaler"]))
          end
        else
          webserver.content_send("<p>No accounts found</p>")
        end
        webserver.content_send("</table><hr>")

        webserver.content_send(format("<table style='width:100%%'>"))
        webserver.content_send("<th>Index</th><th>OBIS</th><th>Unit</th><th>Scaler</th><tr>")
        webserver.content_send("<td style='width:300px'><select name='index' id='indexSelector'>")
        for i:0..(obis_configs.size()-1)
          webserver.content_send(format("<option value='%i'>%i</option>", i, i))
        end
        webserver.content_send("</select></td>")

        webserver.content_send(format(
          "<td style='width:300px'><input type='text' name='obis' value='%s' id='obisInput'></td>",
          obis_configs[0]["obis"]))
        webserver.content_send(format(
          "<td style='width:300px'><input type='text' name='unit' value='%s' id='unitInput'></td>",
          obis_configs[0]["unit"]))
        webserver.content_send(format(
          "<td style='width:300px'><input type='text' name='scaler' value='%s' id='scalerInput'></td>",
          obis_configs[0]["scaler"]))

        webserver.content_send("<script>document.getElementById('indexSelector').addEventListener('change', function() {")
        webserver.content_send("var obis_configs = JSON.parse('" + json.dump(obis_configs) + "');")
        webserver.content_send("document.getElementById('obisInput').value = obis_configs[this.value].obis;")
        webserver.content_send("document.getElementById('unitInput').value = obis_configs[this.value].unit;")
        webserver.content_send("document.getElementById('scalerInput').value = obis_configs[this.value].scaler;")
        webserver.content_send("})")
        webserver.content_send("</script>")
        webserver.content_send("</tr></table>")


        webserver.content_send("<button name='store_obis_config' class='button bgrn'>Save</button>")
        webserver.content_send("</form></p>")

        webserver.content_send(format("<hr><table style='width:100%%'>"))
        webserver.content_send("<th>Symbol</th><th>Address</th><th>Type</th><th>Length</th><tr>")
        var symbols = json.load('{{symbols | json}}')
        for name:symbols.keys()
          webserver.content_send(
            format("<tr><td>%s</td><td>%s</td><td>%i</td><td>%i</td></tr>", 
            name, 
            symbols[name]["address"], 
            symbols[name]["type"], 
            symbols[name]["length"]))
        end
        webserver.content_send("</tr></table>")

        webserver.content_send("<p></p></fieldset><p></p>")

      webserver.content_stop()
    end
    
    def post_lp_uart_sml()
      if !webserver.check_privileged_access() return nil end      
      try
        if webserver.has_arg("store_obis_config")
          # read arguments
          var result = tasmota.cmd(format(
            "set_obis_config %s,%s,%s,%s",
            webserver.arg("index"),
            webserver.arg("obis"),
            webserver.arg("unit"),
            webserver.arg("scaler")))
          print(format("BRY: set_obis_config> '%s'", result))
          webserver.redirect("/lp_uart_sml?")
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
      webserver.on("/lp_uart_sml", / -> self.get_lp_uart_sml(), webserver.HTTP_GET)
      webserver.on("/lp_uart_sml", / -> self.post_lp_uart_sml(), webserver.HTTP_POST)
    end
end  

lp_uart_sml_config.lp_uart_sml_config = lp_uart_sml_config_class()


#- create and register driver in Tasmota -#
if tasmota
  tasmota.add_driver(lp_uart_sml_config.lp_uart_sml_config)
  ## can be removed if put in 'autoexec.bat'
  lp_uart_sml_config.lp_uart_sml_config.web_add_handler()
end

return lp_uart_sml_config

#- For debugging purposes, you can manually call the following to register the web handler -#
#- as it is automatically called only if the instance was registered at startup, for example
#- in `autoexec.be` -#
#-

web_page_demo_instance.web_add_handler()

-#