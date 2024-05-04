#######################################################################
# PowerQuartier accounts UI
#
#######################################################################
import persist
import webserver

var pq_accounts = module('pq_accounts')
  
class PqAccountsUi
  var auid
  def init()
    if ! persist.has("auid")
      self.auid = ""
    else
      self.auid = persist.auid
    end

  end
  
  def web_add_config_button()
    webserver.content_send("<p><form id=pq_accounts action='pq_accounts' style='display: block;' method='get'><button>Select PowerQuartier Account</button></form></p>")
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
  # Display the complete page on `/pq_accounts'
  #######################################################################
  
  def get_pq_accounts()
    if !webserver.check_privileged_access() return nil end
  
      webserver.content_start("PowerQuartier Account")           #- title of the web page -#
      webserver.content_send_style()                  #- send standard Tasmota styles -#
      webserver.content_send("<style>label{display:block;}</style>")
      if persist.has("email") && persist.has("password")
        import powerquartier
        var pqClient = powerquartier.Client(persist.email, bytes().fromb64(persist.password).asstring())
        webserver.content_send("<p>PowerQuartier User: " + pqClient.email + "</p>")
        webserver.content_send(format("<legend><b title='PowerQuartier'>Accounts</b></legend>"))
        webserver.content_send("<p><form id=pq_accounts style='display: block;' action='/pq_accounts' method='post'>")
        webserver.content_send(format("<table style='width:100%%'>"))
        var allByAccounts = pqClient.get_uri("/accountdata/allByAccounts")["data"]
        if (allByAccounts)
          for account:allByAccounts["accounts"]
            var auid = account["auid"]
            webserver.content_send(format("<tr><td><input type='radio' id='%s' name='auid' value='%s'%s/></td><td style='width:100px'><label for='%s'><b>Name</b></label></td>", auid, auid, self.auid == auid ? " checked" : "", auid))
            webserver.content_send(format("<td style='width:300px'><label for='%s'>%s</label></td></tr>", auid,account["name"]))
            for euid:account["entities"].keys()
              var entity = self.findInList(allByAccounts["entities"], "euid", euid)
              if entity != nil
                  webserver.content_send(format("<tr><td/><td style='width:100px'><label for='%s'><b>Adress</b></label></td>", auid))
                  webserver.content_send(format("<td style='width:300px'><label for='%s'><i>%s</i></label></td></tr>", auid, entity["address"]["street"] + " " + entity["address"]["number"] + ", " + entity["address"]["zip"]))
              end
            end
          end
        else
          webserver.content_send("<p>No accounts found</p>")
        end
        webserver.content_send("</table><hr>")
        webserver.content_send("<button name='store_account' class='button bgrn'>Save</button>")
        webserver.content_send("</form></p>")
        webserver.content_send("<p></p></fieldset><p></p>")
      else
        webserver.content_send("<p>No PowerQuartier credentials found</p>")
        webserver.content_send("<p><form id=pq_credentials action='pq_credentials' style='display: block;' method='get'><button>PowerQuartier Credentials</button></form></p>")
      end
      webserver.content_stop()
    end
    
    def post_pq_account()
      if !webserver.check_privileged_access() return nil end      
      try
        if webserver.has_arg("store_account")
          # read arguments
          persist.auid = webserver.arg("auid")
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
      webserver.on("/pq_accounts", / -> self.get_pq_accounts(), webserver.HTTP_GET)
      webserver.on("/pq_accounts", / -> self.post_pq_account(), webserver.HTTP_POST)
    end
end  

pq_accounts.PqAccountsUi=PqAccountsUi


#- create and register driver in Tasmota -#
if tasmota
  var PqAccountsUi_instance = pq_accounts.PqAccountsUi()
  tasmota.add_driver(PqAccountsUi_instance)
  ## can be removed if put in 'autoexec.bat'
  PqAccountsUi_instance.web_add_handler()
end

return pq_accounts

#- For debugging purposes, you can manually call the following to register the web handler -#
#- as it is automatically called only if the instance was registered at startup, for example
#- in `autoexec.be` -#
#-

web_page_demo_instance.web_add_handler()

-#