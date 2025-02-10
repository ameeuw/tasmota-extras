var lp_vars = module('lp_vars')

class lp_vars_class : Driver
    var ulp_sleep_time
    var ulp_iteration
    var ulp_print_variable
    var ulp_float_variable
    var ulp_double_variable
    var ulp_int_variable
    var ulp_uint_variable
    var ulp_bool_variable
    var ulp_string_variable
    
    def get_code()
      return bytes().fromb64("{{code_b64}}")
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

    def read_iteration()
      import ULP
      return ULP.get_mem({{ulp_iteration}})
    end

    def read_print_variable()
      import ULP
      return ULP.get_mem({{ulp_print_variable}})
    end

    def read_float_variable()
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.seti(0,ULP.get_mem({{ulp_float_variable}}),4)
      return float_bytes.getfloat(0)
    end

    def read_int_variable()
      import ULP
      return ULP.get_mem({{ulp_int_variable}})
    end
    
    def read_uint_variable()
      import ULP
      return ULP.get_mem({{ulp_uint_variable}})
    end

    def read_bool_variable()
      import ULP
      return ULP.get_mem({{ulp_bool_variable}}) == 1 ? true : false
    end

    def read_string_variable()
      import ULP
      var length = {{ulp_string_variable_length}}
      var char_bytes = bytes(-4 * (length+1))
      for i:0..length
        char_bytes.seti(i * 4,ULP.get_mem({{ulp_string_variable}}+i), 4)
      end
      return char_bytes.asstring()
    end

    def set_print_variable(value)
      import ULP
      ULP.set_mem({{ulp_print_variable}},value)
      return ULP.get_mem({{ulp_print_variable}})
    end

    #- trigger a read every second -#
    def every_second()
      self.ulp_iteration = self.read_iteration()
      self.ulp_print_variable = self.read_print_variable()
      self.ulp_float_variable = self.read_float_variable()
      self.ulp_int_variable = self.read_int_variable()
      self.ulp_uint_variable = self.read_uint_variable()
      self.ulp_bool_variable = self.read_bool_variable()
      self.ulp_string_variable = self.read_string_variable()
    end
  
    #- display sensor value in the web UI -#
    def web_sensor()
      import string
      var msg = string.format(
               "{s}<hr>{m}<hr>{e}"
               "{s}ULP Variable{m}value:{e}"
               "{s}iteration{m}%i{e}"..
               "{s}print_variable{m}%i{e}"..
               "{s}float_variable{m}%f{e}"..
               "{s}int_variable{m}%i{e}"..
               "{s}uint_variable{m}%u{e}"..
               "{s}bool_variable{m}%s{e}"..
               "{s}string_variable{m}%s{e}",
               self.ulp_iteration,
               self.ulp_print_variable,
               self.ulp_float_variable,
               self.ulp_int_variable,
               self.ulp_uint_variable,
               self.ulp_bool_variable,
               self.ulp_string_variable)
      tasmota.web_send_decimal(msg)
    end
end
lp_vars.lp_vars = lp_vars_class()


if tasmota
  var lp_vars_instance = lp_vars_class()
  tasmota.add_driver(lp_vars_instance)

  def set_print_variable(cmd, idx, payload, payload_json)
    import ULP
    import string
    var result
    if payload != ""
        result = lp_vars_instance.set_print_variable(int(payload))
    end
    tasmota.resp_cmnd(string.format('{"print variable":%i}', result))
  end
  tasmota.add_cmd('lp_vars_variable', set_print_variable)
end

return lp_vars