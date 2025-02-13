var lp_vars = module('lp_vars')

class lp_vars_class : Driver
    var ulp_sleep_time
    var ulp_iteration
    var ulp_float
    var ulp_double
    var ulp_int
    var ulp_uint
    var ulp_bool
    var ulp_string
    
    def get_code()
      return bytes().fromb64("{{binary.base64}}")
    end
  
    def init()
      self.ulp_sleep_time = 1000 * 1000
      import ULP
      ULP.uart_init(4,5,9600,serial.SERIAL_8N1)
      self.init_ulp()
    end
  
    def init_ulp()
      import ULP
      ULP.wake_period(0,self.ulp_sleep_time)
      var c = self.get_code()
      ULP.load(c)
      ULP.run()
    end  

    def get_iteration()
      import ULP
      return ULP.get_mem({{symbols.ulp_iteration.address}})
    end

    def get_float()
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.seti(0,ULP.get_mem({{symbols.ulp_float.address}}),4)
      return float_bytes.getfloat(0)
    end

    def set_float(value)
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.setfloat(0,value)
      ULP.set_mem({{symbols.ulp_float.address}},float_bytes.geti(0,4))
      return self.get_float()
    end

    def get_int()
      import ULP
      return ULP.get_mem({{symbols.ulp_int.address}})
    end

    def set_int(value)
      import ULP
      ULP.set_mem({{symbols.ulp_int.address}},value)
      return self.get_int()
    end
    
    def get_uint()
      import ULP
      return ULP.get_mem({{symbols.ulp_uint.address}})
    end

    def set_uint(value)
      import ULP
      ULP.set_mem({{symbols.ulp_uint.address}},value)
      return self.get_uint()
    end

    def get_bool()
      import ULP
      return ULP.get_mem({{symbols.ulp_bool.address}}) == 1 ? true : false
    end

    def set_bool(value)
      import ULP
      ULP.set_mem({{symbols.ulp_bool.address}},value ? 1 : 0)
      return self.get_bool()
    end

    def get_string()
      import ULP
      var length = {{symbols.ulp_string.length}}
      var char_bytes = bytes(-4 * (length+1))
      for i:0..length
        char_bytes.seti(i * 4,ULP.get_mem({{symbols.ulp_string.address}}+i), 4)
      end
      return char_bytes.asstring()
    end

    def set_string(value)
      import ULP
      var length = {{symbols.ulp_string.length}}
      var char_bytes = bytes().fromstring(value)
      for i:0..length
        ULP.set_mem({{symbols.ulp_string.address}}+i,char_bytes.geti(i * 4,4))
      end
      return self.get_string()
    end

    #- trigger a read every second -#
    def every_second()
      self.ulp_iteration = self.get_iteration()
      self.ulp_float = self.get_float()
      self.ulp_int = self.get_int()
      self.ulp_uint = self.get_uint()
      self.ulp_bool = self.get_bool()
      self.ulp_string = self.get_string()
    end
  
    #- display sensor value in the web UI -#
    def web_sensor()
      import string
      var msg = string.format(
               "{s}<hr>{m}<hr>{e}"
               "{s}ULP Variable{m}value:{e}"
               "{s}iteration{m}%i{e}"..
               "{s}float{m}%f{e}"..
               "{s}int{m}%i{e}"..
               "{s}uint{m}%u{e}"..
               "{s}bool{m}%s{e}"..
               "{s}string{m}%s{e}",
               self.ulp_iteration,
               self.ulp_float,
               self.ulp_int,
               self.ulp_uint,
               self.ulp_bool,
               self.ulp_string)
      tasmota.web_send_decimal(msg)
    end
end
lp_vars.lp_vars = lp_vars_class()


if tasmota
  tasmota.add_driver(lp_vars.lp_vars)

  def set_float(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
        result = lp_vars.lp_vars.set_float(real(payload))
    end
    tasmota.resp_cmnd(string.format('{"float variable":%f}', result))
  end
  tasmota.add_cmd('set_float', set_float)

  def set_int(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
        result = lp_vars.lp_vars.set_int(number(payload))
    end
    tasmota.resp_cmnd(string.format('{"int variable":%i}', result))
  end
  tasmota.add_cmd('set_int', set_int)

  def set_uint(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
        result = lp_vars.lp_vars.set_uint(number(payload))
    end
    tasmota.resp_cmnd(string.format('{"uint variable":%u}', result))
  end
  tasmota.add_cmd('set_uint', set_uint)

  def set_bool(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
        result = lp_vars.lp_vars.set_bool(payload == "true" || payload == "1")
    end
    tasmota.resp_cmnd(string.format('{"bool variable":%s}', result))
  end
  tasmota.add_cmd('set_bool', set_bool)

  def set_string(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
        result = lp_vars.lp_vars.set_string(payload)
    end
    tasmota.resp_cmnd(string.format('{"string variable":%s}', result))
  end
  tasmota.add_cmd('set_string', set_string)
end

return lp_vars