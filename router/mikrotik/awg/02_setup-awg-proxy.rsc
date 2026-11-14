# ============================================================
# AWG Proxy -- MikroTik RouterOS (protocol: v3)
# 2026-11-14 15:21:52
# ============================================================

# 0. Check prerequisites
:if ([:len [/system/package/find where name="container" disabled=no]] = 0) do={
  :put "Container package is not installed or disabled. Install it and reboot."
  :error "Usage: /system/device-mode/update container=yes"
}

# Auto-detect storage
:global awgDisk "disk1"
{
  :local usbFree 0
  :do { :set usbFree [/disk/get [find where mount-point="usb1"] free] } on-error={}
  :if ($usbFree > 0) do={
    :set awgDisk "usb1"
    :put ("Using USB: usb1 (" . ($usbFree / 1048576) . " MB free)")
  } else={
    :if ([:len [/disk/find where slot="usb1"]] > 0) do={
      :put "USB found but not mounted. Format as ext4?"
      :put "Press 'y' to confirm:"
      :local key [/terminal/inkey timeout=30]
      :if ($key = 121 || $key = 89) do={
        /disk/format-drive usb1 file-system=ext4 label=usb1
        :delay 3s
        :do { :set usbFree [/disk/get [find where mount-point="usb1"] free] } on-error={}
        :if ($usbFree > 0) do={
          :set awgDisk "usb1"
        } else={ :put "Format failed, using disk1" }
      } else={ :put "Using disk1" }
    } else={ :put "No USB, using disk1" }
  }
}

# 1. Uninstall and update scripts
/system/script/add name=awg-proxy-1-uninstall comment=awg-proxy-1 source={
  :put "Uninstallimg AmneziaWG..."
  :log info "Uninstallimg AmneziaWG..."
  :local prevDNS ""
  :do { :set prevDNS [/container/envs/get [find where list="awg-proxy-1-env" key="AWG_PREV_DNS"] value] } on-error={}
  :local storageDisk "disk1"
  :do { :set storageDisk [/container/envs/get [find where list="awg-proxy-1-env" key="AWG_STORAGE"] value] } on-error={}
  :local prevTmpdir ""
  :if ($storageDisk != "disk1") do={
    :do { :set prevTmpdir [/container/envs/get [find where list="awg-proxy-1-env" key="AWG_PREV_TMPDIR"] value] } on-error={}
  }
  /ip/route/remove [find where comment=awg-proxy-1-tunnel]
  /ip/route/remove [find where comment=awg-proxy-1-dns]
  :do { /queue/tree/remove [find where comment="awg-proxy-1-ack"] } on-error={}
  :do { /queue/type/remove [find where name="awg-proxy-1-ack"] } on-error={}
  :do { /ip/firewall/mangle/remove [find where comment="awg-proxy-1-ack"] } on-error={}
  :do { /system/scheduler/remove [find where comment~"awg-proxy-1"] } on-error={}
  :do { /system/script/remove [find where comment~"awg-proxy-1" and name!="awg-proxy-1-uninstall"] } on-error={}
  /container/stop [find where interface=veth-awg-proxy-1]
  :delay 7s
  /container/remove [find where interface=veth-awg-proxy-1]
  /container/envs/remove [find where list="awg-proxy-1-env"]
  :if ($prevDNS != "") do={
    :do { /ip/dns/set servers="$prevDNS" } on-error={}
    :put ("DNS restored to: $prevDNS")
  }
  :if ($storageDisk != "disk1") do={
    /container/config set tmpdir=$prevTmpdir
    :put ("Container tmpdir restored to: $prevTmpdir")
  }
  /ip/firewall/nat/remove [find where out-interface="wg-awg-proxy-1"]
  /ip/firewall/nat/remove [find where src-address="172.22.155.240/30"]
  /ip/address/remove [find where address="172.22.155.241/30"]
  :do { /ipv6/firewall/nat/remove [find where comment=awg-proxy-1-v6-nat] } on-error={}
  :do { /ipv6/firewall/nat/remove [find where comment=awg-proxy-1-dstnat6] } on-error={}
  :do { /ipv6/firewall/filter/remove [find where comment=awg-proxy-1-v6-out] } on-error={}
  :do { /ipv6/firewall/filter/remove [find where comment=awg-proxy-1-awg-in6] } on-error={}
  :do { /ipv6/nd/remove [find where interface=veth-awg-proxy-1] } on-error={}
  :do { /ipv6/nd/prefix/remove [find where interface=veth-awg-proxy-1] } on-error={}
  :do { /ipv6/address/remove [find where comment=awg-proxy-1-v6] } on-error={}
  /interface/veth/remove [find where name="veth-awg-proxy-1"]
  /interface/wireguard/peers/remove [find where interface="wg-awg-proxy-1"]
  /ip/address/remove [find where interface="wg-awg-proxy-1"]
  /interface/wireguard/remove [find where name="wg-awg-proxy-1"]
  :do { /file/remove [find where name~"awg-proxy-1.+tar"] } on-error={}
  :do { /file/remove [find where name=($storageDisk . "/awg-proxy-1")] } on-error={}
  :do { /file/remove [find where name=($storageDisk . "/ru_ranges_timeout.rsc")] } on-error={}
  :do { /file/remove [find where name=($storageDisk . "/ru_ranges.rsc")] } on-error={}
  :if ($storageDisk != "disk1") do={
    :do { /file/remove [find where name~($storageDisk . "/pull")] } on-error={}
  }
  :put "Uninstall AmneziaWG Proxy complete!"
  :log info "Uninstall AmneziaWG Proxy complete!"
  /system/script/remove [find where name=awg-proxy-1-uninstall]
}
/system/script/add name=awg-proxy-1-update comment=awg-proxy-1 source={
  :local cids [/container/find where interface=veth-awg-proxy-1 and !stopped]
  :if ([:len $cids] = 0) do={ :set cids [/container/find where interface=veth-awg-proxy-1 and start-on-boot=yes] }
  :if ([:len $cids] = 0) do={ :set cids [/container/find where interface=veth-awg-proxy-1] }
  :if ([:len $cids] = 0) do={
    :put "Container awg-proxy-1 not found"
    :log warning "awg-proxy-1-update: container not found"
  } else={
    :local cid [:pick $cids ([:len $cids] - 1)]
    :local img [/container/get $cid remote-image]
    :local ver [/system/resource/get version]
    :local dotPos [:find $ver "."]
    :local rest ([:pick $ver ($dotPos + 1) [:len $ver]] . " ")
    :local minor 0
    :local mi 0
    :while ([:typeof [:find "0123456789" [:pick $rest $mi ($mi + 1)]]] != "nil") do={ :set minor ($minor * 10 + [:tonum [:pick $rest $mi ($mi + 1)]]); :set mi ($mi + 1) }
    :local wantRunning true
    :do { :if ([/container/get $cid start-on-boot] != true) do={ :set wantRunning false } } on-error={}
    :local healthy true
    :if ([:len [/container/get $cid image-id]] = 0) do={ :set healthy false }
    :if ($wantRunning) do={
      :do { :if ([/container/get $cid stopped] = true) do={ :set healthy false } } on-error={}
    }
    :if (!$healthy && $wantRunning && [:len [/container/get $cid image-id]] > 0) do={
      :put "Container is down - trying to start it"
      :do { /container/start $cid } on-error={}
      :delay 8s
      :set healthy true
      :do { :if ([/container/get $cid stopped] = true) do={ :set healthy false } } on-error={}
      :if ($healthy) do={
        :put "Container is back up"
        :log info "awg-proxy-1: container restarted by the update script"
      }
    }
    :local priv true
    :do { :set priv [[:parse ":return [/container/get $cid privileged]"]] } on-error={}
    :if ($priv != true && $wantRunning && $healthy) do={
      :put "Enabling privileged mode once - it lifts the socket receive buffer cap"
      :log info "awg-proxy-1: enabling privileged mode"
      :do { /container/stop $cid } on-error={}
      :delay 12s
      :do { [:parse "/container/set $cid privileged=yes"] } on-error={}
      :do { /container/start $cid } on-error={}
      :delay 8s
      :do { :if ([/container/get $cid stopped] = true) do={ :set healthy false } } on-error={}
    }
    :if ($img = "" && $minor >= 22 && !$healthy) do={
      :local imgTag "latest"
      :local rbModel ""
      :do { :set rbModel [[:parse ":return [/system/routerboard/get model]"]] } on-error={}
      :local bName [/system/resource/get board-name]
      :if ($rbModel~"E50UG" || $rbModel~"E60iUGS" || $rbModel~"E62iUGS" || $bName~"E50UG" || $bName~"E60iUGS" || $bName~"E62iUGS" || $bName~"^hEX" || $bName~"^hAP ax S") do={
        :set imgTag "latest-armv5"
      }
      :set img ("ghcr.io/timbrs/awg-proxy:" . $imgTag)
      :put ("Container is down and was installed from a file - pointing it at " . $img)
      :log warning "awg-proxy-1-update: broken file install, switching to the registry"
      :do { /container/set $cid remote-image=$img } on-error={}
    }
    :if ($img = "") do={
      :put "Installed from a local image file - /container/repull only updates registry installs."
      :put "Reinstall with the configurator on RouterOS 7.22+ to switch to one-command updates."
    } else={
      :if ($minor < 22) do={
        :put ("/container/repull needs RouterOS 7.22+, this router runs " . $ver)
        :if (!$healthy) do={ :log error ("awg-proxy-1-update: container is down, and " . $ver . " has no /container/repull") }
      } else={
        :local rootDir [/container/get $cid root-dir]
        :if ([:pick $rootDir 0 1] = "/") do={ :set rootDir [:pick $rootDir 1 [:len $rootDir]] }
        :local rootDirOrig $rootDir
        :local slashPos [:find $rootDir "/"]
        :local disk $rootDir
        :if ([:typeof $slashPos] != "nil") do={ :set disk [:pick $rootDir 0 $slashPos] }
        :local verPath "awg-proxy-1-update-check.json"
        :if ($disk != "disk1") do={
          :do { /file/make-directory ($disk . "/pull") } on-error={}
          /container/config set tmpdir=($disk . "/pull")
          :set verPath ($disk . "/pull/awg-proxy-1-update-check.json")
        }
        :local newVer ""
        :do {
          /tool/fetch url="https://api.github.com/repos/timbrs/amneziawg-mikrotik-c/releases/latest" dst-path=$verPath http-max-redirect-count=10
          :local relJson [/file/get [find where name=$verPath] contents]
          :local tagPos [:find $relJson "\"tag_name\":\""]
          :if ([:typeof $tagPos] != "nil") do={
            :local tagRest [:pick $relJson ($tagPos + 12) [:len $relJson]]
            :set newVer [:pick $tagRest 0 [:find $tagRest "\""]]
          }
          :do { /file/remove [find where name=$verPath] } on-error={}
        } on-error={ :put "Could not read the published version" }
        :local curVer ""
        :do { :set curVer [/container/envs/get [find where list="awg-proxy-1-env" key="AWG_IMAGE_VER"] value] } on-error={}
        :local doPull true
        :if ($healthy) do={
          :if ($newVer = "") do={
            :set doPull false
            :put "Published version unknown - leaving the healthy container alone"
          }
          :if ($newVer != "" && $newVer = $curVer) do={
            :set doPull false
            :put ("Already on " . $curVer . " - nothing to pull, tunnel untouched")
          }
        }
        :if ($doPull) do={
          :if (!$healthy) do={
            :put "Container is not healthy - pulling the image again"
            :log warning "awg-proxy-1-update: container unhealthy, forcing a pull"
          }
          :put ("Updating " . $img . " ...")
          :log info "awg-proxy-1: repull started"
          :do { /file/remove [find where name~($rootDirOrig . ".backup")] } on-error={}
          :do { [:parse "/container/set $cid ignore-remote-image-change=yes"] } on-error={}
          /container/repull $cid
          :local waited 0
          :while ([:len [/container/get $cid image-id]] = 0 && $waited < 180) do={
            :delay 3s
            :set waited ($waited + 3)
          }
          :if ([:len [/container/get $cid image-id]] = 0) do={
            :put "Pull failed - retrying once in 15s"
            :delay 15s
            /container/repull $cid
            :set waited 0
            :while ([:len [/container/get $cid image-id]] = 0 && $waited < 180) do={
              :delay 3s
              :set waited ($waited + 3)
            }
          }
          :local backUp false
          :if ([:len [/container/get $cid image-id]] > 0) do={
            :set backUp true
            :if ($wantRunning) do={
              :delay 3s
              :do { /container/start $cid } on-error={}
              :delay 8s
              :set backUp false
              :do { :if ([/container/get $cid stopped] != true) do={ :set backUp true } } on-error={}
            }
          }
          :if (!$backUp) do={
            :put "Container did not come back up - rebuilding it from the registry"
            :log warning "awg-proxy-1-update: container did not come back, rebuilding"
            :do { /container/stop $cid } on-error={}
            :delay 5s
            :do { /container/remove $cid } on-error={}
            :delay 3s
            :do { /file/remove [find where name~($rootDirOrig . ".backup")] } on-error={}
            :do { /container/add remote-image=$img interface=veth-awg-proxy-1 envlist=awg-proxy-1-env hostname=awg-proxy-1 root-dir=$rootDirOrig logging=no start-on-boot=yes comment=awg-proxy-1 } on-error={}
            :set waited 0
            :local newCids [/container/find where interface=veth-awg-proxy-1 and start-on-boot=yes]
            :if ([:len $newCids] = 0) do={ :set newCids [/container/find where interface=veth-awg-proxy-1] }
            :while ([:len $newCids] > 0 && [:len [/container/get [:pick $newCids ([:len $newCids] - 1)] image-id]] = 0 && $waited < 180) do={
              :delay 3s
              :set waited ($waited + 3)
            }
            :if ([:len $newCids] > 0 && [:len [/container/get [:pick $newCids ([:len $newCids] - 1)] image-id]] > 0) do={
              :do { /container/set [:pick $newCids ([:len $newCids] - 1)] shm-size=4M } on-error={}
              :do { [:parse "/container/set [find where interface=veth-awg-proxy-1] ignore-remote-image-change=yes"] } on-error={}
              :do { [:parse "/container/set [find where interface=veth-awg-proxy-1] restart-policy=on-failure restart-interval=30s restart-max-count=10"] } on-error={}
              :do { [:parse "/container/set [find where interface=veth-awg-proxy-1] privileged=yes"] } on-error={}
              :if ($minor >= 24) do={
                :local cDns ""
                :do { :set cDns [/container/envs/get [find where list="awg-proxy-1-env" key="AWG_DNS"] value] } on-error={}
                :local dnsId [:pick $newCids ([:len $newCids] - 1)]
                :local defDns 1
                :do { :set defDns [:len [[:parse ":return [/container/get $dnsId default-dns]"]]] } on-error={}
                :if ($cDns != "" || $defDns = 0) do={ :do { [:parse "/container/set [find where interface=veth-awg-proxy-1] dns=\"$cDns\""] } on-error={} }
              }
              :do { /container/start [:pick $newCids ([:len $newCids] - 1)] } on-error={}
              :delay 8s
              :do { :if ([/container/get [:pick $newCids ([:len $newCids] - 1)] stopped] != true) do={ :set backUp true } } on-error={}
            }
            :if ($backUp) do={
              :put "Container rebuilt"
              :log info "awg-proxy-1: container rebuilt after update"
            } else={
              :put "Rebuild failed - the tunnel is down. Netwatch keeps the router online meanwhile."
              :put "This script runs again on the next schedule and will retry."
              :log error "awg-proxy-1-update: rebuild failed, tunnel is down"
            }
          }
          :if ($backUp && $newVer != "") do={
            :do { /container/envs/remove [find where list="awg-proxy-1-env" key="AWG_IMAGE_VER"] } on-error={}
            :do { /container/envs/add list=awg-proxy-1-env key=AWG_IMAGE_VER value=$newVer } on-error={}
          }
          :do { /file/remove [find where name~($rootDirOrig . ".backup")] } on-error={}
          :if ($backUp) do={
            :put ("Update done: " . $img)
            :log info "awg-proxy-1: update done"
          }
        }
      }
    }
  }
}
# Daily update check. Skipped if scheduler is not allowed by device-mode
{
  :local schedOk true
  :do { :set schedOk [/system/device-mode/get scheduler] } on-error={}
  :if ($schedOk) do={
    /system/scheduler/add name=awg-proxy-1-update on-event="/system/script/run awg-proxy-1-update" start-time=04:30:00 interval=1d comment=awg-proxy-1
  } else={
    :put "WARNING: scheduler not allowed by device-mode, no daily update check."
    :put "Update by hand: /system/script/run awg-proxy-1-update"
    :put "To allow it: /system/device-mode/update scheduler=yes"
  }
}

# 2. Network infrastructure
/interface/veth/add name=veth-awg-proxy-1 address=172.22.155.242/30 gateway=172.22.155.241
/ip/address/add address=172.22.155.241/30 interface=veth-awg-proxy-1
/ip/firewall/nat/add chain=srcnat action=masquerade src-address=172.22.155.240/30

# 3. WireGuard interface (MikroTik derives the public key automatically)
/interface/wireguard/add name=wg-awg-proxy-1 private-key="7tfMpei04zlrBOYHvE0BCWkQ5H1cN2ZkhBwcTHPHD6Q=" listen-port=39289 disabled=yes
/interface/wireguard/peers/add interface=wg-awg-proxy-1 public-key="nbG15bFgLPy53x6RIuZYkq51/ugCyYn0UyBmQACDsG0=" preshared-key="SPs+J1A9R1si1VSEGJkXHMMVf1mq2QNzYUYamLqsWmw=" endpoint-address=172.22.155.242 endpoint-port=51820 allowed-address=0.0.0.0/0,::/0 persistent-keepalive=27
/ip/address/add address=100.108.105.161/32 interface=wg-awg-proxy-1

# Thin out TCP ACKs going into the tunnel (64-bit routers with 4+ cores)
:if (([/system/resource/get architecture-name] = "arm64") && ([/system/resource/get cpu-count] >= 4)) do={
  :do {
    /queue/type/add name=awg-proxy-1-ack kind=cake cake-ack-filter=aggressive cake-flowmode=triple-isolate
    /ip/firewall/mangle/add chain=forward action=mark-packet new-packet-mark=awg-proxy-1-ack passthrough=yes protocol=tcp packet-size=0-80 tcp-flags=ack,!syn,!fin,!rst out-interface=wg-awg-proxy-1 comment=awg-proxy-1-ack
    /queue/tree/add name=awg-proxy-1-ack parent=wg-awg-proxy-1 packet-mark=awg-proxy-1-ack queue=awg-proxy-1-ack max-limit=4M comment=awg-proxy-1-ack
  } on-error={ :put "ACK thinning skipped" }
}

# 4. Container environment variables
/container/envs/add list=awg-proxy-1-env key=AWG_LISTEN value=":51820"
/container/envs/add list=awg-proxy-1-env key=AWG_REMOTE value="153.76.213.73:9911"
/container/envs/add list=awg-proxy-1-env key=AWG_JC value="6"
/container/envs/add list=awg-proxy-1-env key=AWG_JMIN value="10"
/container/envs/add list=awg-proxy-1-env key=AWG_JMAX value="80"
/container/envs/add list=awg-proxy-1-env key=AWG_S1 value="856"
/container/envs/add list=awg-proxy-1-env key=AWG_S2 value="61"
/container/envs/add list=awg-proxy-1-env key=AWG_H1 value="1"
/container/envs/add list=awg-proxy-1-env key=AWG_H2 value="2"
/container/envs/add list=awg-proxy-1-env key=AWG_H3 value="3"
/container/envs/add list=awg-proxy-1-env key=AWG_H4 value="4"
/container/envs/add list=awg-proxy-1-env key=AWG_SERVER_PUB value="nbG15bFgLPy53x6RIuZYkq51/ugCyYn0UyBmQACDsG0="
/container/envs/add list=awg-proxy-1-env key=AWG_CLIENT_PUB value=[/interface/wireguard/get [find name=wg-awg-proxy-1] public-key]
/container/envs/add list=awg-proxy-1-env key=AWG_S3 value="766"
/container/envs/add list=awg-proxy-1-env key=AWG_S4 value="12"
/container/envs/add list=awg-proxy-1-env key=AWG_I1 value="<b 0x000100402112a442><r 12><b 0x000600103030313343382d435045303041314232><b 0xc001000e42696e64696e67204368616e67650000><b 0x00080014><r 20>"
/container/envs/add list=awg-proxy-1-env key=AWG_HEADER_PROTECTION_KEY value="EKo3ntQvkKcFnwsa3GAExnJbjCy/XmJcVI74//+xgng="
/container/envs/add list=awg-proxy-1-env key=AWG_CONTENT_PADDING value="10-100"
/container/envs/add list=awg-proxy-1-env key=AWG_REKEY_AFTER value="100-120"
/container/envs/add list=awg-proxy-1-env key=AWG_REKEY_TIMEOUT value="3-8"
/container/envs/add list=awg-proxy-1-env key=AWG_REJECT_AFTER value="150-180"
/container/envs/add list=awg-proxy-1-env key=AWG_KEEPALIVE_TIMEOUT value="7-13"
/container/envs/add list=awg-proxy-1-env key=AWG_MAX_HANDSHAKE_ATTEMPTS value="15-20"
/container/envs/add list=awg-proxy-1-env key=AWG_NO_DF value="1"
# NOTE on MTU: the value above assumes this tunnel is the last hop.
#   If the server forwards your traffic into another tunnel, subtract
#   that tunnel's overhead too, or every packet leaves in two fragments.

# 5. DNS
{ :local rawDNS [/ip/dns/get servers]; :local prevDNS ""; :foreach s in=[:toarray $rawDNS] do={ :if ([:len $prevDNS] > 0) do={ :set prevDNS "$prevDNS,$s" } else={ :set prevDNS $s } }; /container/envs/add list=awg-proxy-1-env key=AWG_PREV_DNS value="$prevDNS" }
# NOTE: replaces existing DNS configuration
/ip/dns/set servers=100.64.0.1,8.8.4.4
# DNS 100.64.0.1 идёт общим маршрутом (в активный туннель / default),
# без привязки к wg-awg-proxy-1: иначе падение туннеля уносит с собой резолв.
# DNS 8.8.4.4 идёт общим маршрутом (в активный туннель / default),
# без привязки к wg-awg-proxy-1: иначе падение туннеля уносит с собой резолв.

# 6. Download, create and start container
/container/envs/add list=awg-proxy-1-env key=AWG_STORAGE value=$awgDisk
:if ($awgDisk != "disk1") do={
  :local tmpPath ($awgDisk . "/pull")
  /container/envs/add list=awg-proxy-1-env key=AWG_PREV_TMPDIR value=[/container/config/get tmpdir]
  /container/config set tmpdir=$tmpPath memory-high=200M
}
{
  :local arch [/system/resource/get architecture-name]
  :local ver [/system/resource/get version]
  :local dotPos [:find $ver "."]
  :local rest ([:pick $ver ($dotPos + 1) [:len $ver]] . " ")
  :local minor 0
  :local mi 0
  :while ([:typeof [:find "0123456789" [:pick $rest $mi ($mi + 1)]]] != "nil") do={ :set minor ($minor * 10 + [:tonum [:pick $rest $mi ($mi + 1)]]); :set mi ($mi + 1) }
  :local suffix ""
  :if ($minor <= 20) do={ :set suffix "-7.20-Docker" }
  :local file ""
  :local imgTag "latest"
  :if ($arch = "arm64") do={ :set file ("awg-proxy-arm64" . $suffix . ".tar.gz") }
  :if ($arch = "arm") do={
    :set file ("awg-proxy-arm" . $suffix . ".tar.gz")
    :local rbModel ""
    :do { :set rbModel [[:parse ":return [/system/routerboard/get model]"]] } on-error={}
    :local bName [/system/resource/get board-name]
    :if ($rbModel~"E50UG" || $rbModel~"E60iUGS" || $rbModel~"E62iUGS" || $bName~"E50UG" || $bName~"E60iUGS" || $bName~"E62iUGS" || $bName~"^hEX" || $bName~"^hAP ax S") do={
      :set file ("awg-proxy-armv5" . $suffix . ".tar.gz")
      :set imgTag "latest-armv5"
    }
  }
  :if ($arch ~ "x86") do={ :set file ("awg-proxy-amd64" . $suffix . ".tar.gz") }
  :if ($file = "") do={ :error "Unsupported architecture: $arch" }
  :local url "https://github.com/timbrs/amneziawg-mikrotik-c/releases/latest/download/$file"
  :local filePath $file
  :local altPath ("disk1/" . $file)
  :local rootDir ($awgDisk . "/awg-proxy-1")
  :if ($awgDisk != "disk1") do={
    :set filePath ($awgDisk . "/pull/" . $file)
    :set altPath ($awgDisk . "/" . $file)
    :do { /file/make-directory ($awgDisk . "/pull") } on-error={}
  }
  :if ([:len [/file/find where name=$filePath]] = 0 && [:len [/file/find where name=$altPath]] > 0) do={
    :set filePath $altPath
  }
  :local added false
  :local fetched false
  :if ([:len [/file/find where name=$filePath]] > 0) do={
    :put ("Using image already on the router: " . $filePath)
    /container/add file=$filePath interface=veth-awg-proxy-1 envlist=awg-proxy-1-env hostname=awg-proxy-1 root-dir=$rootDir logging=no start-on-boot=yes comment=awg-proxy-1
    :set added true
  }
  :if (!$added && $minor >= 22) do={
    :local img ("ghcr.io/timbrs/awg-proxy:" . $imgTag)
    :put ("Pulling " . $img)
    /container/add remote-image=$img interface=veth-awg-proxy-1 envlist=awg-proxy-1-env hostname=awg-proxy-1 root-dir=$rootDir logging=no start-on-boot=yes comment=awg-proxy-1
    :local cids [/container/find where interface=veth-awg-proxy-1]
    :local waited 0
    :while ([:len $cids] > 0 && [:len [/container/get [:pick $cids 0] image-id]] = 0 && $waited < 120) do={
      :delay 2s
      :set waited ($waited + 2)
    }
    :if ([:len $cids] > 0 && [:len [/container/get [:pick $cids 0] image-id]] > 0) do={
      :set added true
      :put ("Pulled from registry in " . $waited . "s")
      :do {
        :local verPath ($filePath . ".rel")
        /tool/fetch url="https://api.github.com/repos/timbrs/amneziawg-mikrotik-c/releases/latest" dst-path=$verPath http-max-redirect-count=10
        :local relJson [/file/get [find where name=$verPath] contents]
        :local tagPos [:find $relJson "\"tag_name\":\""]
        :local tagRest [:pick $relJson ($tagPos + 12) [:len $relJson]]
        /container/envs/add list=awg-proxy-1-env key=AWG_IMAGE_VER value=[:pick $tagRest 0 [:find $tagRest "\""]]
        /file/remove [find where name=$verPath]
      } on-error={}
    } else={
      :put "Registry unavailable, falling back to the release archive"
      :do { /container/remove $cids } on-error={}
      :delay 2s
    }
  }
  :if (!$added) do={
    :local freeStorage 0
    :if ($awgDisk = "disk1") do={
      :set freeStorage [/system/resource/get free-hdd-space]
    } else={
      :do { :set freeStorage [/disk/get [find where mount-point=$awgDisk] free] } on-error={}
    }
    :if ($freeStorage < 262144) do={
      :put ("WARNING: Low disk space (" . ($freeStorage / 1024) . "KB free). Need at least 256KB.")
      :put "See: https://github.com/timbrs/amneziawg-mikrotik-c#insufficient-disk-space"
      :error "Insufficient disk space"
    }
    :put ("Fetching: $url -> " . $filePath)
    /tool/fetch url=$url dst-path=$filePath http-max-redirect-count=10
    /container/add file=$filePath interface=veth-awg-proxy-1 envlist=awg-proxy-1-env hostname=awg-proxy-1 root-dir=$rootDir logging=no start-on-boot=yes comment=awg-proxy-1
    :set fetched true
  }
  :if ($minor > 20) do={ [:parse "/container/set [find where interface=veth-awg-proxy-1] shm-size=4M"] }
  :do { [:parse "/container/set [find where interface=veth-awg-proxy-1] ignore-remote-image-change=yes"] } on-error={}
  :do { [:parse "/container/set [find where interface=veth-awg-proxy-1] restart-policy=on-failure restart-interval=30s restart-max-count=10"] } on-error={}
  :do { [:parse "/container/set [find where interface=veth-awg-proxy-1] privileged=yes"] } on-error={}
  :if ($minor >= 24) do={
    :local cDns ""
    :do { :set cDns [/container/envs/get [find where list="awg-proxy-1-env" key="AWG_DNS"] value] } on-error={}
    :do { [:parse "/container/set [find where interface=veth-awg-proxy-1] dns=\"$cDns\""] } on-error={}
  }
  :if ($fetched) do={ /file/remove $filePath }
  :local freeMem [/system/resource/get free-memory]
  :if ($freeMem < 16777216) do={
    :put ("WARNING: Low memory (" . ($freeMem / 1048576) . "MB free). 16MB+ recommended.")
  }
  /container/start [find where interface=veth-awg-proxy-1]
  :do { /file/remove [find where name="console-dump.txt"] } on-error={}
  :put "Waiting for container to start..."
  :delay 5s
  /interface/wireguard/enable wg-awg-proxy-1
  :put "WireGuard interface enabled"
  :put "Installation complete!"
  :put "Ping test: 100.64.0.1 via AmneziaWG tunnel. repeat 10 times"
  /ping 100.64.0.1 count=10 interval=1
  :put ""
  :put "======= NEXT STEPS ======="
  :put ""
  :put "Route specific traffic through the AmneziaWG tunnel:"
  :put ""
  :put "  Route a single host:"
  :put "    /ip/route/add dst-address=8.8.8.8/32 gateway=wg-awg-proxy-1 comment=awg-proxy-1-tunnel"
  :put ""
  :put "  Route a subnet:"
  :put "    /ip/route/add dst-address=100.0.0.0/8 gateway=wg-awg-proxy-1 comment=awg-proxy-1-tunnel"
  :put ""
  :put "  Remove a route:"
  :put "    /ip/route/remove [find where comment=awg-proxy-1-tunnel dst-address=8.8.8.8/32]"
  :put ""
  :put "  Show all tunnel routes:"
  :put "    /ip/route/print where comment=awg-proxy-1-tunnel"
  :put ""
  :put "  Update the container:"
  :put "    /system/script/run awg-proxy-1-update"
  :put ""
  :put "  Uninstall:"
  :put "    /system/script/run awg-proxy-1-uninstall"
  :put "========================="
}

# 7. Verification
# /container/print
# /interface/wireguard/print
# /interface/wireguard/peers/print
