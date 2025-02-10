var lp_uart_sml = module('lp_uart_sml')

class lp_uart_sml_class : Driver
    var ulp_sleep_time
    var ulp_iteration
    var ulp_print_variable
    var ulp_sml_t1wh
    var ulp_sml_sumwh
    
    def get_code()
      return bytes().fromb64("{{code_b64}}")
    end
  
    def init()
      self.ulp_sleep_time = 5 * 1000 * 1000
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
      return ULP.get_mem({{ulp_iteration}})
    end

    def get_t1wh()
      return self.get_float({{ulp_sml_t1wh}})
    end

    def get_sumwh()
      return self.get_float({{ulp_sml_sumwh}})
    end

    def get_float(address)
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.seti(0,ULP.get_mem(address),4)
      return float_bytes.getfloat(0)
    end

    def set_float(address, value)
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.setfloat(0,value)
      ULP.set_mem(address,float_bytes.geti(0,4))
      return self.get_float(address)
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

    #- trigger a read every second -#
    def every_second()
      self.ulp_iteration = self.get_iteration()
      self.ulp_print_variable = self.get_print_variable()
      self.ulp_sml_t1wh = self.get_t1wh()
      self.ulp_sml_sumwh = self.get_sumwh()
    end
  
    #- display sensor value in the web UI -#
    def web_sensor()
      import string
      var msg = string.format(
               "{s}<hr>{m}<hr>{e}"
               "{s}ULP Variable{m}value:{e}"
               "{s}iteration{m}%i{e}"..
               "{s}t1wh{m}%f{e}"..
               "{s}sumwh{m}%f{e}"..
               "{s}print_variable{m}%i{e}",
               self.ulp_iteration,
               self.ulp_sml_t1wh,
               self.ulp_sml_sumwh,
               self.ulp_print_variable)
      tasmota.web_send_decimal(msg)
    end
  
    #- add sensor value to teleperiod -#
    def json_append()
      import string
      var msg = string.format(",\"ULP\":{\"iteration\":%i}",
                                   self.ulp_iteration)
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