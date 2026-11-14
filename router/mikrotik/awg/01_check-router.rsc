:put "=== awg-proxy: checking the router ==="
:put "This changes nothing. Lines marked ! need your attention."
:put ""
:local problems 0
:local ver [/system/resource/get version]
:put ("RouterOS version: " . $ver)
:local dotPos [:find $ver "."]
:local rest ([:pick $ver ($dotPos + 1) [:len $ver]] . " ")
:local minor 0
:local mi 0
:while ([:typeof [:find "0123456789" [:pick $rest $mi ($mi + 1)]]] != "nil") do={ :set minor ($minor * 10 + [:tonum [:pick $rest $mi ($mi + 1)]]); :set mi ($mi + 1) }
:if ($minor < 24) do={
:put "  ! 7.24 or newer is needed for full speed (privileged container)."
:put "    Without it the proxy still works, but upload stays about 3x slower."
:put "    Update: System > Packages > Check For Updates, then reboot."
  :set problems ($problems + 1)
} else={
:put "  ok: this version supports the privileged container (full speed)"
}
:if ($minor < 22) do={
:put "  ! 7.22 or newer is needed to update the container with one command."
:put "    On older versions updating means reinstalling."
}
:put ""
:local hasCont false
:do { :if ([:len [/system/package/find where name~"container"]] > 0) do={ :set hasCont true } } on-error={}
:if (!$hasCont) do={
:put "  ! the container package is NOT installed."
:put "    Download \"Extra packages\" for your architecture from mikrotik.com,"
:put "    upload container-*.npk to Files and reboot."
  :set problems ($problems + 1)
} else={
:put "  ok: container package is installed"
}
:local dmC false; :local dmF false; :local dmS false
:do { :set dmC [/system/device-mode/get container] } on-error={}
:do { :set dmF [/system/device-mode/get fetch] } on-error={}
:do { :set dmS [/system/device-mode/get scheduler] } on-error={}
:if (!$dmC || !$dmF) do={
:put "  ! device-mode does not allow containers or fetch yet. Run:"
:put "      /system/device-mode/update container=yes fetch=yes scheduler=yes"
:put "    The router will ask you to confirm with the Reset button or a reboot."
  :set problems ($problems + 1)
} else={
:put "  ok: device-mode allows containers and fetch"
}
:if (!$dmS) do={
:put "  ! device-mode does not allow the scheduler: daily update checks"
:put "    and the RU address list will not be installed. Same command as above."
}
:put ""
:local arch [/system/resource/get architecture-name]
:put ("Architecture: " . $arch . "  (this decides which image you need)")
:local cores [/system/resource/get cpu-count]
:if ($cores >= 4 && $arch != "arm") do={
:put ("Cores: " . $cores . "  - enough for the performance settings")
} else={
:put ("Cores: " . $cores . " (" . $arch . ")  - performance settings will be skipped, that is correct here")
}
:local mem (([/system/resource/get free-memory]) / 1048576)
:if ($mem < 16) do={
:put ("  ! Free memory: " . $mem . " MB. 16 MB or more is recommended.")
:put "    Close what you can, or reboot the router before installing."
  :set problems ($problems + 1)
} else={
:put ("Free memory: " . $mem . " MB")
}
:local freeKB (([/system/resource/get free-hdd-space]) / 1024)
:local usb ""
:do { :foreach d in=[/disk/find where type="hardware"] do={
  :local mp [/disk/get $d mount-point]
  :if ([:len $mp] > 0 && [:len $usb] = 0) do={ :set usb $mp }
} } on-error={}
:if ([:len $usb] > 0) do={
:put ("Storage: USB drive \"" . $usb . "\" is mounted - the container will live there")
} else={
:put ("Storage: internal memory, " . $freeKB . " KB free")
  :if ($freeKB < 600) do={
:put "  ! less than 600 KB free. The image needs about 300 KB, and the RU"
:put "    address list needs 1.5 MB more. Plug in a USB drive, or free space:"
:put "      /file/print   then remove what you do not need"
    :set problems ($problems + 1)
  }
}
:put ""
:local yr [:tonum [:pick [/system/clock/get date] 0 4]]
:if ($yr < 2024) do={
:put ("  ! The router clock says " . [/system/clock/get date] . " - that is wrong.")
:put "    Downloads over https will fail. Fix the time first:"
:put "      /system/ntp/client/set enabled=yes servers=216.239.35.0,162.159.200.1"
  :set problems ($problems + 1)
} else={
:put "ok: the clock looks sane (https downloads need it)"
}
:local dns [/ip/dns/get servers]
:if ([:len $dns] = 0) do={
:put "  ! no DNS server is set. Downloads will fail. For example:"
:put "      /ip/dns/set servers=8.8.8.8,1.1.1.1"
  :set problems ($problems + 1)
} else={
:put ("DNS servers: " . [:tostr $dns])
}
:local resolved ""
:do { :set resolved [:resolve "github.com"] } on-error={}
:if ([:len $resolved] = 0) do={
:put "  ! the router cannot resolve github.com."
:put "    Either DNS is broken, or the router has no internet at all."
:put "    If GitHub is blocked for you, tick \"Offline mode\" in the configurator."
  :set problems ($problems + 1)
} else={
:put "ok: name resolution works"
}
:put ""
:foreach n in={"LAN";"WAN"} do={
  :if ([:len [/interface/list/find where name=$n]] = 0) do={
:put ("  ! interface list " . $n . " does not exist. Create it:")
:put ("      /interface/list/add name=" . $n)
:put ("      /interface/list/member/add list=" . $n . " interface=<your interface>")
    :set problems ($problems + 1)
  } else={
:put ("ok: interface list " . $n . " exists")
  }
}
:local already [:len [/container/find]]
:if ($already > 0) do={
:put ("")
:put ("Containers already on this router: " . $already . ". Existing tunnels:")
  :foreach c in=[/container/find] do={
    :local nm ""; :do { :set nm [/container/get $c name] } on-error={}
    :local pr false; :do { :set pr [/container/get $c privileged] } on-error={}
    :if ($pr = true) do={
:put ("  " . $nm . " - privileged mode ON")
    } else={
:put ("  " . $nm . " - privileged mode OFF (this one is losing speed)")
    }
  }
}
:put ("")
:if ($problems = 0) do={
:put "=== Everything is ready. Go ahead and run the install commands. ==="
} else={
:put ("=== " . $problems . " thing(s) to fix first - see the ! lines above ===")
}