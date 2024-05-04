#######################################################################
# PowerQuartier credentials UI
#
#######################################################################
import persist
import webserver

var pg_credentials = module('pg_credentials')
  
class PqCredentialsUi
  var email, password
  def init()
    if ! persist.has("email")
      self.email = ""
    else
      self.email = persist.email
    end
    if ! persist.has("password")
      self.password= ""
    else
      self.password = bytes().fromb64(persist.password).asstring()
    end
  end
  
  def web_add_config_button()
    webserver.content_send("<p><form id=pq_credentials action='pq_credentials' style='display: block;' method='get'><button>PowerQuartier Credentials</button></form></p>")
  end   
  
  #######################################################################
  # Display the complete page on `/pq_credentials'
  #######################################################################
  
  def get_pq_credentials()
    if !webserver.check_privileged_access() return nil end
  
      webserver.content_start("PowerQuartier Credentials")           #- title of the web page -#
      webserver.content_send_style()                  #- send standard Tasmota styles -#
      webserver.content_send("<fieldset><style>.bdis{background:#888;}.bdis:hover{background:#888;}</style>")
      webserver.content_send(format("<legend><b title='PowerQuartier'>Credentials</b></legend>"))
      webserver.content_send("<p><form id=pq_credentials style='display: block;' action='/pq_credentials' method='post'>")
      webserver.content_send(format("<table style='width:100%%'>"))
      webserver.content_send("<tr><td style='width:100px'><b>Email:</b></td>")
      webserver.content_send(format("<td style='width:300px'><input type='email' name='email' value='%s'></td></tr>", self.email))
      webserver.content_send("<tr><td style='width:100px'><b>Password</b></td>")
      webserver.content_send(format("<td style='width:300px'><input type='password' name='password' value='%s'></td></tr>", self.password))
      webserver.content_send("</table><hr>")
      webserver.content_send("<button name='store_credentials' class='button bgrn'>Save</button>")
      webserver.content_send("</form></p>")
      webserver.content_send("<p></p></fieldset><p></p>")
      webserver.content_button(webserver.BUTTON_CONFIGURATION)
      webserver.content_stop()
    end
    
    def post_pq_credentials()
      if !webserver.check_privileged_access() return nil end      
      try
        if webserver.has_arg("store_credentials")
          # read arguments
          persist.email = webserver.arg("email")
          persist.password = bytes().fromstring(webserver.arg("password")).tob64()
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
      webserver.on("/pq_credentials", / -> self.get_pq_credentials(), webserver.HTTP_GET)
      webserver.on("/pq_credentials", / -> self.post_pq_credentials(), webserver.HTTP_POST)
    end
end  

pg_credentials.PqCredentialsUi=PqCredentialsUi


#- create and register driver in Tasmota -#
if tasmota
  var PqCredentialsUi_instance = pg_credentials.PqCredentialsUi()
  tasmota.add_driver(PqCredentialsUi_instance)
  ## can be removed if put in 'autoexec.bat'
  PqCredentialsUi_instance.web_add_handler()
end

return pg_credentials

#- For debugging purposes, you can manually call the following to register the web handler -#
#- as it is automatically called only if the instance was registered at startup, for example
#- in `autoexec.be` -#
#-

web_page_demo_instance.web_add_handler()

-#