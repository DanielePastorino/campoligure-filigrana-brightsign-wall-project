Library "prj\utilsplus.brs"
Library "prj\nexmosphere.brs"

Sub Main(cfg as Dynamic)
    objConfig =  ReadConfigJson("..\\config\\config.json")

    ' Abilito la funzionalità delle zone.
    ' Quando le zone sono abilitate l'image layer sta sempre davanti al video layer.
    ' Quando invece le zone non sono abilitate l'image layer non è visibile se c'è un video in riproduzione, e viceversa.
    EnableZoneSupport(false)

    ' la messagePort in ascolto sugli eventi
    messagePort = CreateObject("roMessagePort")

    ' =========== VIDEO CONFIG =========== 
    ' Risoluzione dello schermo ("1920x1080x60p", "1024x768x60p", "1280x800x60p", "1360x768x60")
    screenMode = objConfig.video.screenmode
    videoMode = CreateObject("roVideoMode")
    ' Imposto la modalità video e recupero le info
    videoMode.SetMode(screenMode)

    ' =========== AUDIO CONFIG ===========
    ' Audio output
    if (objConfig.audio.hdmi) then
        audioOutput = CreateObject("roAudioOutput", "HDMI")
    else
        audioOutput = CreateObject("roAudioOutput", "analog")
    end if

    ' =========== WALL CONFIG ===========
    ptpDomain =  objConfig.wall.ptp
    regSec = CreateObject("roRegistrySection", "networking")
    ptp = regSec.Read("ptp_domain")

    if (ptp <> ptpDomain) then
        regSec.Write("ptp_domain", ptpDomain)
        regSec.Flush()
        RebootSystem()
    end if

    syncArray = CreateObject("roAssociativeArray")
    syncArray.Domain = objConfig.wall.domain
    if objConfig.wall.MulticastAddress <> invalid or objConfig.wall.MulticastAddress = "" then
        syncArray.MulticastAddress = objConfig.wall.MulticastAddress
    else
        syncArray.MulticastAddress = "224.0.126.10"
    end if
    if objConfig.wall.MulticastPort <> invalid or objConfig.wall.MulticastPort = "" then
        syncArray.MulticastPort = objConfig.wall.MulticastPort
    else
        syncArray.MulticastPort = "1539"
    end if
    print "#MulticastAddress: ";syncArray.MulticastAddress
    print "#MulticastPort: ";syncArray.MulticastPort
    syncManager = CreateObject("roSyncManager", syncArray)
    syncManager.SetPort(messagePort)
    syncManager.SetMasterMode(true)

    print "ptp ";regSec.Read("ptp_domain")

    ' =========== UDP SENDER/RECEIVER ====
	' receiver
	udpReceiver = CreateObject("roDatagramReceiver", objConfig.udp.receiver.port)
	udpReceiver.SetPort(messagePort)

    ' =========== VIDEOS ===========
    videoPlayer = CreateObject("roVideoPlayer")
    videoPlayer.SetPort(messagePort)
    videoPlayer.SetPcmAudioOutputs(audioOutput)
    videoPlayer.SetViewMode(1) '0 = stretch, 1 = no stretch
    videoPlayer.SetTransform(objConfig.video.rotation)
    videoPlayer.SetLoopMode(false) ' loop

    ' =========== OTHER CONFIG ===========
    loopObj = objConfig.media.loop
	signalObj = objConfig.media.signal

	regexObj = CreateObject("roRegex", ";", "")
	isPlayingSignal = false

	print "NAME:";objConfig.name

'****************************
'* 		   MAIN LOOP		*
'****************************

_MainLoop:

    ' Playing LOOP
    isPlayingSignal = false
	print "-(LOOP)"
	' WALL MASTER
	sm = syncManager.Synchronize(loopObj, 0)
	print "SEND: ";loopObj;" FILE: ";loopObj
	vd = CreateObject("roAssociativeArray")
	vd.Filename = loopObj
	vd.SyncDomain = sm.GetDomain()
	vd.SyncId = sm.GetId()
	vd.SyncIsoTimestamp = sm.GetIsoTimestamp()
	videoPlayer.PlayFile(vd)

_MsgLoop:

    ' Attende senza timeout che arrivi un messaggio
    msgReceived = wait(0, messagePort)
    
    ' Evento UDP (PIR UDP)
	if type(msgReceived) = "roDatagramEvent" and not isPlayingSignal then
		udpReceived = msgReceived.GetString()
		udpReceived = udpReceived.trim()
		print ">RECEIVED:";udpReceived

		lineSplit = regexObj.Split(udpReceived)
		if lineSplit <> invalid and lineSplit.Count() = 2 then
			' è per me?
			if lineSplit[0] = objConfig.name then
				if lineSplit[1] = "1" then
					isPlayingSignal = true
					' PLAY del video
					print "->PLAY: ";signalObj
					' WALL MASTER
					sm = syncManager.Synchronize(signalObj, 0)
					print "SEND: ";signalObj;" FILE: ";signalObj
					vd = CreateObject("roAssociativeArray")
					vd.Filename = signalObj
					vd.SyncDomain = sm.GetDomain()
					vd.SyncId = sm.GetId()
					vd.SyncIsoTimestamp = sm.GetIsoTimestamp()
					videoPlayer.PlayFile(vd)
				end if
			end if
		end if

    ' Evento video
    else if type(msgReceived) = "roVideoEvent" then

        ' Evento fine video
        if msgReceived.GetInt() = 8 then
            goto _MainLoop
        end if

    end if

    goto _MsgLoop

End Sub