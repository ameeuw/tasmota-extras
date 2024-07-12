import webserver


def takepicandconvert(frameNumber, toFormat)
    tasmota.cmd("wcgetframe ".. frameNumber)
    tasmota.cmd("wcconvertframe" .. frameNumber .. " " .. toFormat)
end

# read a picture (jpg) from tas as bytes and return them
def getpicasbytes(n)
    # get an image
    var cmd = "Wcgetpicstore" .. n
    var resobj = tasmota.cmd(cmd);
    # returns `WCGetpicstore:{"addr":123456,"len":12345,"w":160,"h":120, "format":5}`
    var addr = resobj['WCGetpicstore']['addr']
    var len = resobj['WCGetpicstore']['len']
    if len
        print('got picture')
        import introspect
        var p = introspect.toptr(addr) # p is now of type ptr:
        var b = bytes(p, len) # b is now an unmanaged bytes object:  b.ismapped() should return true
        return b
    else 
        print('no picture')
        return nil
    end
end

def indexAreaFromBytesFloat32(width, height, top, left, dimX, dimY, picbytes)
    var inputTensor = bytes(-dimX * dimY * 3 * 4) # rgb, 32bit float
    for y:0..dimY-1
        for x:0..dimX-1
            for channel:0..2
                var index = (left + x) * 3 + (top + y) * width * 3 + channel
                inputTensor.setfloat((x + y * dimX) * 3 * 4 + channel, picbytes.get(index))
            end
        end
    end
    return inputTensor
end

def indexAreaFromBytesUint8(width, height, top, left, dimX, dimY, picbytes)
    var inputTensor = bytes(-dimX * dimY * 3) # rgb888
    for y:0..dimY-1
        for x:0..dimX-1
            for channel:0..2
                var index = (left + x) * 3 + (top + y) * width * 3 + channel
                inputTensor.set((x + y * dimX) * 3 + channel, picbytes.get(index))
            end
        end
    end
    return inputTensor
end



class PqVisionUi
    var config
    var status
    def init()
    end
    
  
    
      def get_pq_bytes()
        if !webserver.check_privileged_access() return nil end

        var top = 0
        var left = 0
        var dimX = 20
        var dimY = 32

        if (webserver.arg("top") != nil && (webserver.arg("left") != nil))
            print("top: " .. webserver.arg("top"))
            print("left: " .. webserver.arg("left"))
            top = int(webserver.arg("top"))
            left = int(webserver.arg("left"))
        end

        if (webserver.arg("dimX") != nil && (webserver.arg("dimY") != nil))
            print("dimX: " .. webserver.arg("dimX"))
            print("dimY: " .. webserver.arg("dimY"))
            dimX = int(webserver.arg("dimX"))
            dimY = int(webserver.arg("dimY"))
        end

        takepicandconvert(1,6)
        var a = getpicasbytes(1)
        print(a.size())
        var b = indexAreaFromBytesUint8(160,120, top, left, dimX, dimY, a)
        print(b.size())
        webserver.content_response(b.tob64())
      end
      
      #- ---------------------------------------------------------------------- -#
      # respond to web_add_handler() event to register web listeners
      #- ---------------------------------------------------------------------- -#
      #- this is called at Tasmota start-up, as soon as Wifi/Eth is up and web server running -#
        
      def web_add_handler()
        #- we need to register a closure, not just a function, that captures the current instance -#
        webserver.on("/pq_bytes", / -> self.get_pq_bytes(), webserver.HTTP_GET)
      end
  end  


#- create and register driver in Tasmota -#
# if tasmota
#   var PqVisionUi_instance = pq_vision.PqBatteryUi()
#   tasmota.add_driver(PqBatteryUi_instance)
#   ## can be removed if put in 'autoexec.bat'
#   PqBatteryUi_instance.web_add_handler()
# end

# return pq_battery

#- For debugging purposes, you can manually call the following to register the web handler -#
#- as it is automatically called only if the instance was registered at startup, for example
#- in `autoexec.be` -#

var PqVisionUi_instance = PqVisionUi()

PqVisionUi_instance.web_add_handler()
