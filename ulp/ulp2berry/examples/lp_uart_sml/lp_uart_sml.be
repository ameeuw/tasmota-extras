var lp_uart_sml = module('lp_uart_sml')

class ulp_class : Driver
    var ulp_sleep_time
    
    def get_code()
      return bytes().fromb64("{{binary.base64}}")
    end
  
    def init_ulp()
      self.ulp_sleep_time = 5 * 1000 * 1000
      import ULP
      ULP.wake_period(0,self.ulp_sleep_time)
      var c = self.get_code()
      ULP.load(c)
      ULP.run()
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
end

class lp_uart_sml_class : ulp_class
    var ser

    def init()
      import ULP
      ULP.uart_init(4,5,9600,serial.SERIAL_8N1)
      self.ser = serial(6,7, 9600, serial.SERIAL_8N1)
      self.init_ulp()
    end

    def get_obis_configs()
      var obis_configs_length = {{symbols.ulp_obis_configs.length}}
      var obis_config_size = 2
      var obis_configs_list = []
      for i:0..((obis_configs_length/obis_config_size)-1)
        obis_configs_list.push(self.get_obis_config(i))
      end
      return obis_configs_list
    end

    def get_obis_config(index)
      import ULP
      var obis_config_bytes = bytes(-8)
      obis_config_bytes.seti(0,ULP.get_mem({{symbols.ulp_obis_configs.address}}+index*2),4)
      obis_config_bytes.seti(4,ULP.get_mem({{symbols.ulp_obis_configs.address}}+index*2+1),4)
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
      ULP.set_mem({{symbols.ulp_obis_configs.address}}+index*2,obis_config[0..3].geti(0,4))
      ULP.set_mem({{symbols.ulp_obis_configs.address}}+index*2+1,obis_config[4..7].geti(0,4))
      return self.get_obis_config(index)
    end

    def get_iteration()
      import ULP
      return ULP.get_mem({{symbols.ulp_iteration.address}})
    end

    def get_obis_value(index)
      return self.get_float({{symbols.ulp_obis_values.address}},index)
    end

    def get_obis_values()
      var obis_configs_length = {{symbols.ulp_obis_configs.length}}
      var obis_config_size = 2
      var obis_values_list = []
      for i:0..((obis_configs_length/obis_config_size)-1)
        var obis_config = self.get_obis_config(i)
        obis_config["value"] = self.get_obis_value(i)
        obis_values_list.push(obis_config)
      end
      return obis_values_list
    end

    def get_print_variable()
      import ULP
      return ULP.get_mem({{symbols.ulp_print_variable.address}})
    end

    def set_print_variable(value)
      import ULP
      ULP.set_mem({{symbols.ulp_print_variable.address}},value)
      return ULP.get_mem({{symbols.ulp_print_variable.address}})
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
    import string
    var result
    if payload != ""
      result = lp_uart_sml.lp_uart_sml.set_print_variable(int(payload))
    end
    tasmota.resp_cmnd(string.format('{"print variable":%i}', result))
  end
  tasmota.add_cmd('set_print_variable', set_print_variable)

  def get_obis_value(cmd, idx, payload, payload_json)
    import json
    var result
    if payload != ""
        result = lp_uart_sml.lp_uart_sml.get_obis_value(int(payload))
    end
    tasmota.resp_cmnd(result)
  end
  tasmota.add_cmd('get_obis_value', get_obis_value)

  def get_obis_values(cmd, idx, payload, payload_json)
    import json
    var result = lp_uart_sml.lp_uart_sml.get_obis_values()
    tasmota.resp_cmnd(json.dump(result))
  end
  tasmota.add_cmd('get_obis_values', get_obis_values)

  def get_obis_configs(cmd, idx, payload, payload_json)
    import json
    var result = lp_uart_sml.lp_uart_sml.get_obis_configs()
    tasmota.resp_cmnd(json.dump(result))
  end
  tasmota.add_cmd('get_obis_configs', get_obis_configs)

  def get_obis_config(cmd, idx, payload, payload_json)
    import json
    var result
    if payload != ""
        result = lp_uart_sml.lp_uart_sml.get_obis_config(int(payload))
    end
    tasmota.resp_cmnd(json.dump(result))
  end
  tasmota.add_cmd('get_obis_config', get_obis_config)

  def set_obis_config(cmd, idx, payload, payload_json)
    import json
    import string
    var result
    if payload_json != nil
      result = lp_uart_sml.lp_uart_sml.set_obis_config(
        int(payload_json["index"]),
        payload_json["obis"],
        int(payload_json["unit"]),
        int(payload_json["scaler"]))
    else
      if payload != ""
        var payload_split = string.split(payload, ",")
        result = lp_uart_sml.lp_uart_sml.set_obis_config(
          int(payload_split[0]),
          payload_split[1],
          int(payload_split[2]),
          int(payload_split[3]))
      end
    end

    tasmota.resp_cmnd(json.dump(result))
  end
  tasmota.add_cmd('set_obis_config', set_obis_config)

end

lp_uart_sml.lp_uart_sml.send_ehz_bin()

return lp_uart_sml