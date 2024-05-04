import display
import string

var CST816S_address = 0x15
var gesture_map = {
  0x00: 0,
  0x01: 16,
  0x02: 17,
  0x03: 18,
  0x04: 19,
  0x05: 0,
  0x0B: 0,
  0x0C: 0,
}

class CST816SDriver
    var wire
  
    def init(wire, irq, rst)
      self.wire = wire
      tasmota.delay(50)
      gpio.pin_mode(irq, gpio.PULLDOWN)
      gpio.pin_mode(rst, gpio.OUTPUT)
      gpio.digital_write(rst, gpio.HIGH)
      tasmota.delay(50)
      gpio.digital_write(rst, gpio.LOW)
      tasmota.delay(5)
      gpio.digital_write(rst, gpio.HIGH)
      tasmota.delay(50)
      self.wire.read_bytes(CST816S_address, 0x15 , 1)
      tasmota.delay(5)
      self.wire.read_bytes(CST816S_address, 0xA7 , 3)
      # Check for free Counter
      for (var i = 0; i < 3; i++)
        # Break if Counter and not already attached to irq pin
        if (gpio.pin(gpio.CNTR1, i) == irq) 
          break
        else
          # If Counter i is unused
          if (gpio.pin(gpio.CNTR1, i) == -1)
            # Attach Counter i (peripheral 352-355) to irq pin
            tasmota.cmd(string.format("GPIO%d %d", irq, 352+i))
            break
          end
        end
      end
    end
  
    def every_100ms()
    # def every_second()
      if (gpio.counter_read(0))
        var data = self.wire.read_bytes(CST816S_address, 0x01 , 6)
        var x = ((data[2] & 0xF) << 8) + data[3]
        var y = ((data[4] & 0xF) << 8) + data[5]
        var gesture = data[0]
        print("x: ", x, " y: ", y, " gesture: ", gesture_map[gesture])
        display.touch_update(1, x, y, gesture_map[gesture])
        gpio.counter_set(0, 0)
      else
        display.touch_update(0, 0, 0, 0)
      end
    end
  end

d1 = CST816SDriver(wire1,1,0)
tasmota.add_driver(d1)