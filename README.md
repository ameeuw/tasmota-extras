### Tasmota Extras
```
.
├── apps/
│   ├── dist
│   ├── pack.sh
│   └── README.md
├── autoconfs/
│   ├── dist
│   ├── pack.sh
│   └── README.md
├── esp8266
├── ulp/
│   ├── dist
│   ├── examples
│   ├── soc
│   ├── assemble.py
│   ├── defines.db
│   ├── Dockerfile
│   └── README.md
└── README.md
```

#### /apps

Holds sources and a packing script for Tasmota applications which are packed as ".tapp" bundle.

#### /autoconfs

Holds sources for auto configurations of various devices and a packing script for Tasmota autoconfs which are packed as ".autoconf" bundle.

#### /esp8266

Holds sources for scripts and init.bat for esp8266 Tasmota projects.

#### /ulp

Holds sources for ULP based applications plus a toolchain (Dockerfile) that builds a berry script fore programming the ULP and communicating with RTC-memory.