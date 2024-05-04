class HCSR04Driver
    var ser, distance
  
    def init(txpin)
      self.ser = serial(txpin, -1, 9600, serial.SERIAL_8N1)
    end
  
    def every_second()
      if !self.ser return nil end
      self.get_distance()
    end
  
    def get_distance()
      var reading = self.ser.read()
      if ((reading[0] + reading[1] + reading[2] - 256) == reading[3])
        print("ok")
        self.distance = reading.get(1,-2)
      else
        print("sum mismatch")
        return nil
      end
    end
  
      #- display sensor value in the web UI -#
    def web_sensor()
      if !self.ser return nil end
      import string
      var msg = string.format("{s}HC-SR04 distance{m}%d mm{e}",self.distance)
      tasmota.web_send_decimal(msg)
    end
  end
  
#   d1 = HCSR04Driver(26)
  
#   tasmota.add_driver(d1)