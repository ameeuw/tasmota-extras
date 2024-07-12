
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

def saveraw()
    var picbytes = getpicasbytes(1)
    if picbytes
        var f = open('/pic.bmp', 'w')
        f.write(picbytes)
        f.close()
    end
end

# options: options struture, picnum 0-4, relpath relative to options['basefolder']
# save to either SD or post to web if options['http']
def savepicraw(options, picnum, relpath)
    if options['http']
        # post to web
        var picbytes = self.getpicasbytes(picnum);
        if picbytes
            self.posttoweb(options, relpath, picbytes)
        end
    else
        # save to local FS using tas function
        var cmd = "wcsavepic" .. picnum .." ".. options['basefolder'] .. '/' .. relpath
        var resobj = tasmota.cmd(cmd);
        print('saved pic '..cmd..resobj)
    end
end


def indexAreaFromBytes(width, height, top, left, dimX, dimY, picbytes)
    var inputTensor = bytes(-dimX*dimY*3*4) # rgb, 32bit float
    for i:0..dimY-1
        for j:0..dimX-1
            for channel:0..2
                inputTensor.setfloat(4*i+j+channel,picbytes.getfloat((top + i) * width + left + j + channel*4))
            end
        end
    end
    return inputTensor
end

indexAreaFromBytes(96,96, 0,0, 32, 20, getpicasbytes(1))

takepicandconvert(1,6)
a = getpicasbytes(1)
print(a.size())
a.tob64()