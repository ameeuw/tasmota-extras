Template {"NAME":"ESP32-Coolbox","GPIO":[1,1,1,1,640,1,1,1,1,1216,352,608,1024,1,1,1,0,1,1,1,0,416,417,1312,0,0,0,0,224,225,4866,4867,1,0,4736,4737],"FLAG":0,"BASE":1}
Module 0
DeviceName Coolbox

; Enable individual PWM Channels
SetOption68 1
SetOption15 1
PWMFrequency 20000

; Temperature sensor flow in & out
adcparam1 2,10000,8000,3820,0
adcparam2 2,10000,8000,3820,0

; Current sensor TEC1 & TEC2
adcparam3 6,0,4095,0,21290
adcparam4 6,0,4095,0,21290

; Flowmeter counter 1 & 2
teleperiod 60
rule1 on tele-counter#c1>0 do counter1 0 endon
rule1 on
rule2 on tele-counter#c2>0 do counter2 0 endon
rule2 on

; Display
displayRotate 2
displayRows 8
displayRefresh 1
displayMode 2

; Initialise outputs
power1 off
power2 off
power3 off
power4 off
power5 on