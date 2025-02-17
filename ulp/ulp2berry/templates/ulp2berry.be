# ULP2Berry Module
# This module provides a driver class for interfacing with the ESP32's Ultra Low Power (ULP) coprocessor.
# It handles initialization, memory operations, and data type conversions between Berry and ULP.

var ulp2berry = module('ulp2berry')

# ULP2Berry driver class
# Provides methods to interact with the ULP coprocessor, including memory operations
# and data type conversions
class ulp2berry_class : Driver
    var ulp_sleep_time
  
    # Returns the ULP binary code as a byte array
    # The binary is embedded as a base64 string during template processing
    # @return bytes The ULP binary code
    def get_code()
      return bytes().fromb64("{{binary.base64}}")
    end
  
    # Initializes the ULP coprocessor
    # Sets up the wake period and loads the binary code
    def init_ulp()
      self.ulp_sleep_time = 5 * 1000 * 1000  # 5 seconds in microseconds
      import ULP
      ULP.wake_period(0, self.ulp_sleep_time)
      ULP.load(self.get_code())
      ULP.run()
    end

    # Reads a float value from ULP memory
    # @param address int The base memory address to read from
    # @param index int (optional) Offset from the base address, defaults to 0
    # @return float The value read from memory
    def get_float(address, index)
      if index == nil
        index = 0
      end
      
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.seti(0, ULP.get_mem(address+index), 4)
      return float_bytes.getfloat(0)
    end

    # Writes a float value to ULP memory
    # @param value float The value to write
    # @param address int The base memory address to write to
    # @param index int (optional) Offset from the base address, defaults to 0
    # @return float The value read back from memory for verification
    def set_float(value, address, index)
      if index == nil
        index = 0
      end
      import ULP
      var float_bytes = bytes(-4)
      float_bytes.setfloat(0, value)
      ULP.set_mem(address + index, float_bytes.geti(0,4))
      return self.get_float(address, index)
    end

    # Reads an integer value from ULP memory
    # @param address int The base memory address to read from
    # @param index int (optional) Offset from the base address, defaults to 0
    # @return int The value read from memory
    def get_int(address, index)
      if index == nil
        index = 0
      end
      import ULP
      return ULP.get_mem(address+index)
    end

    # Writes an integer value to ULP memory
    # @param value int The value to write
    # @param address int The base memory address to write to
    # @param index int (optional) Offset from the base address, defaults to 0
    # @return int The value read back from memory for verification
    def set_int(value, address, index)
      if index == nil
        index = 0
      end
      import ULP
      ULP.set_mem(address + index, value)
      return self.get_int(address, index)
    end

    # Reads a string value from ULP memory
    # @param address int The base memory address to read from
    # @param length int The number of 4-byte words to read
    # @return string The string read from memory
    def get_string(address, length)
      import ULP
      var char_bytes = bytes(-4 * (length+1))
      for i:0..length
        char_bytes.seti(i * 4, ULP.get_mem(address+i), 4)
      end
      return char_bytes.asstring()
    end

    # Writes a string value to ULP memory
    # @param value string The string to write
    # @param address int The base memory address to write to
    # @param length int The number of 4-byte words to write
    # @return string The string read back from memory for verification
    def set_string(value, address, length)
      import ULP
      var char_bytes = bytes().fromstring(value)
      for i:0..length
        ULP.set_mem(address+i, char_bytes.geti(i * 4, 4))
      end
      return self.get_string(address, length)
    end
end

# Register the class in the module
ulp2berry.ulp2berry_class = ulp2berry_class

return ulp2berry