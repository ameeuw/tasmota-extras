var app
var wd = tasmota.wd
def init()
    if !tasmota.wifi()["up"]
        print(wd)
        print("WiFi not available - timeout 10 seconds")
        tasmota.set_timer(10000,init)
        return
    else
        import sys
        if size(wd) sys.path().push(wd) end
        print(wd)
        import pq_app
        app = pq_app.PqApp()
        import pq_credentials
        import pq_accounts
        if size(wd) sys.path().pop() end
    end
end

if !app
    init()
end