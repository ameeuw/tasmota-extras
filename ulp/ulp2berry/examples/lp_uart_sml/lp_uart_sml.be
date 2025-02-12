var lp_uart_sml = module('lp_uart_sml')

class lp_uart_sml_class : Driver
    var ulp_sleep_time
    var ser
    
    def get_code()
      return bytes().fromb64("{{code_b64}}")
    end
  
    def init()
      self.ulp_sleep_time = 5 * 1000 * 1000
      import ULP
      ULP.uart_init(4,5,9600,serial.SERIAL_8N1)
      self.ser = serial(6,7, 9600, serial.SERIAL_8N1)
      self.init_ulp()
    end
  
    def init_ulp()
      import ULP
      ULP.wake_period(0,self.ulp_sleep_time)
      var c = self.get_code()
      ULP.load(c)
      ULP.run()
    end

    def get_obis_configs()
      import ULP
      var length = {{ulp_obis_configs_length}}
      var obis_configs = bytes(-4 * (length+1))
      for i:0..length
        obis_configs.seti(i * 4,ULP.get_mem({{ulp_obis_configs}}+i),4)
      end
      var obis_configs_list = []
      for i:0..(length/2)
        var obis_config = {}
        var currentPosition = i*8;
        obis_config["obis"] = obis_configs[(currentPosition)..(currentPosition+5)].tohex()
        obis_config["unit"] = obis_configs.geti(currentPosition+6,1)
        obis_config["scaler"] = obis_configs.geti(currentPosition+7,1)
        obis_configs_list.push(obis_config)
      end
      return obis_configs_list
    end

    def get_obis_config(index)
      import ULP
      var obis_config_bytes = bytes(-8)
      obis_config_bytes.seti(0,ULP.get_mem({{ulp_obis_configs}}+index*2),4)
      obis_config_bytes.seti(4,ULP.get_mem({{ulp_obis_configs}}+index*2+1),4)
      var obis_config = {}
      var currentPosition = 0;
      obis_config["obis"] = obis_config_bytes[(currentPosition)..(currentPosition+5)].tohex()
      obis_config["unit"] = obis_config_bytes.geti(currentPosition+6,1)
      obis_config["scaler"] = obis_config_bytes.geti(currentPosition+7,1)
      return obis_config
    end

    def set_obis_config(index, obis, unit, scaler)
      import ULP
      var obis_config = bytes(obis)
      var unit_bytes = bytes(-1)
      unit_bytes.seti(0,unit,1)
      obis_config = obis_config + unit_bytes
      var scaler_bytes = bytes(-1)
      scaler_bytes.seti(0,scaler,1)
      obis_config = obis_config + scaler_bytes
      ULP.set_mem({{ulp_obis_configs}}+index*2,obis_config[0..3].geti(0,4))
      ULP.set_mem({{ulp_obis_configs}}+index*2+1,obis_config[4..7].geti(0,4))
      return self.get_obis_config(index)
    end

    def get_iteration()
      import ULP
      return ULP.get_mem({{ulp_iteration}})
    end

    def get_float(address, index)
      if index == nil
        index = 0
      end
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.seti(0,ULP.get_mem(address+index),4)
      return float_bytes.getfloat(0)
    end

    def set_float(address, value)
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.setfloat(0,value)
      ULP.set_mem(address,float_bytes.geti(0,4))
      return self.get_float(address)
    end

    def get_obis_value(index)
      return self.get_float({{ulp_obis_values}},index)
    end

    def get_print_variable()
      import ULP
      return ULP.get_mem({{ulp_print_variable}})
    end

    def set_print_variable(value)
      import ULP
      ULP.set_mem({{ulp_print_variable}},value)
      return ULP.get_mem({{ulp_print_variable}})
    end

    def send_uart_message(message)
      self.ser.write(message)
    end

    def send_ehz_bin()
      var ehz_bin =bytes("1b1b1b1b010101017607000c0408872d620062007263010176010107000c069e2d0f0b06454d4801001d4615ca0101632b8e007607000c0408872e620062007263070177010b06454d4801001d4615ca0172620165069efa837777078181c78203ff0101010104454d480177070100000009ff010101010b06454d4801001d4615ca0177070100010800ff63018201621e52ff5600000074ea0177070100010801ff0101621e52ff59000000000012d6870177070100010802ff0101621e52ff56000000000001770701000f0700ff0101621b52ff5500002f650177078181c78205ff010101018302ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff01010163b93f007607000c0408873162006200726302017101636a5300001b1b1b1b1a01b69d")
      self.send_uart_message(ehz_bin)
    end

    #- trigger a read every second -#
    def every_second()
    end
  
    #- display sensor value in the web UI -#
    def web_sensor()
      import string
      var msg = string.format(
               "{s}<hr>{m}<hr>{e}"
               "{s}ULP Variable{m}value:{e}"
               "{s}iteration{m}%i{e}"..
               "{s}obis_values[0]{m}%f{e}"..
               "{s}obis_values[1]{m}%f{e}"..
               "{s}print_variable{m}%i{e}",
               self.get_iteration(),
               self.get_obis_value(0),
               self.get_obis_value(1),
               self.get_print_variable())
      tasmota.web_send_decimal(msg)
    end
  
    #- add sensor value to teleperiod -#
    def json_append()
      import string
      var msg = string.format(",\"ULP\":{\"iteration\":%i}",
                                   self.get_iteration())
      tasmota.response_append(msg)
    end
end
lp_uart_sml.lp_uart_sml = lp_uart_sml_class()


if tasmota
  tasmota.add_driver(lp_uart_sml.lp_uart_sml)

  def set_print_variable(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
        result = lp_uart_sml.lp_uart_sml.set_print_variable(int(payload))
    end
    tasmota.resp_cmnd(string.format('{"print variable":%i}', result))
  end
  tasmota.add_cmd('set_print_variable', set_print_variable)

end

return lp_uart_sml