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

    ' sender
	udpSender = CreateObject("roDatagramSender")

    ' =========== VIDEOS ===========
    videoPlayer = CreateObject("roVideoPlayer")
    videoPlayer.SetPort(messagePort)
    videoPlayer.SetPcmAudioOutputs(audioOutput)
    videoPlayer.SetViewMode(1) '0 = stretch, 1 = no stretch
    videoPlayer.SetTransform(objConfig.video.rotation)
    videoPlayer.SetLoopMode(false) ' loop

    ' =========== OTHER CONFIG ===========
    loopObj = objConfig.media.loop
	signalObj_it = objConfig.media.signal_it
    signalObj_en = objConfig.media.signal_en

    jsonObj = invalid
	if objConfig.video_event.file <> invalid and objConfig.video_event.file <> "" then
		jsonObj = ParseLightsFromJson(objConfig.video_event.file)
		print "***Video Events loaded ";jsonObj
	end if

	regexObj = CreateObject("roRegex", ";", "")
	isPlayingSignal = false

	print "NAME:";objConfig.name

'****************************
'* 		   MAIN LOOP		*
'****************************

_MainLoop:

    ' Init luci
	if jsonObj <> invalid then
		For Each c in jsonObj.init
			print "-(UDP Sender) ";c.type;" ";c.cmd;" to ";c.ip;":";c.port
			udpSender.SetDestination(c.ip, c.port)
			udpSender.Send(c.cmd)
		End For
	end if 

    ' Playing LOOP
    isPlayingSignal = false
	
	' WALL MASTER
    print "-(LOOP)"
	sm = syncManager.Synchronize(loopObj, 0)
	print "SEND: ";loopObj;" FILE: ";loopObj
	vd = CreateObject("roAssociativeArray")
	vd.Filename = loopObj
	vd.SyncDomain = sm.GetDomain()
	vd.SyncId = sm.GetId()
	vd.SyncIsoTimestamp = sm.GetIsoTimestamp()
    videoPlayer.ClearEvents()
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
                    signalObj = signalObj_it
                else 
                    signalObj = signalObj_en
                end if

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
                videoPlayer.ClearEvents()
                if jsonObj <> invalid then
                    print "*** create video events"
                    CreateVideoEventInMillisencond(jsonObj, videoPlayer)
                end if
                videoPlayer.PlayFile(vd)
			end if
		end if

    ' Evento video
    else if type(msgReceived) = "roVideoEvent" then

        'Eventi video (luci) solo se gira in signal e sono abilitati gli eventi
		if msgReceived.GetInt() = 12 and jsonObj.events <> invalid then
            
			eventId = msgReceived.GetData()
			actionsLights = jsonObj.events[eventId].actions	
            print ".... eventId: ";eventId
			if actionsLights <> invalid then
				' SEND UDP
				print "#TIME: ";jsonObj.events[eventId].time
				For Each c in actionsLights
					print ">(UDP Sender) ";c.type;" ";c.cmd;" to ";c.ip;":";c.port
					udpSender.SetDestination(c.ip, c.port)
					udpSender.Send(c.cmd)
				End for
			end if
        ' Evento fine video
        else if msgReceived.GetInt() = 8 then
            goto _MainLoop
        end if

    end if

    goto _MsgLoop

End Sub