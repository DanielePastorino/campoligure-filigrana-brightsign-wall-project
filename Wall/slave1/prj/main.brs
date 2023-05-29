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
	syncManager.SetMasterMode(false)
	
	print "ptp ";regSec.Read("ptp_domain")

    ' =========== VIDEOS ===========
    videoPlayer = CreateObject("roVideoPlayer")
    videoPlayer.SetPort(messagePort)
    videoPlayer.SetPcmAudioOutputs(audioOutput)
    videoPlayer.SetViewMode(1) '0 = stretch, 1 = no stretch
    videoPlayer.SetTransform(objConfig.video.rotation)
    videoPlayer.SetLoopMode(false) ' loop

    ' =========== OTHER CONFIG ===========
    ' ...

'****************************
'* 		   MAIN LOOP		*
'****************************

_MainLoop:

    ' ...

_MsgLoop:

    ' Attende senza timeout che arrivi un messaggio
    msgReceived = wait(0, messagePort)
    
    'Evento WALL
	if type(msgReceived) = "roSyncManagerEvent" then

		videoPath = msgReceived.GetId()
		print "RECEIVED: ";videoPath;" FILE: ";videoPath

		vd = CreateObject("roAssociativeArray")
		vd.Filename = videoPath
		vd.SyncDomain = msgReceived.GetDomain()
		vd.SyncId = msgReceived.GetId()
		vd.SyncIsoTimestamp = msgReceived.GetIsoTimestamp()
		videoPlayer.PlayFile(vd)

    ' Evento video
    else if type(msgReceived) = "roVideoEvent" then

        ' Evento fine video
        if msgReceived.GetInt() = 8 then
            
            goto _MainLoop

        end if

    end if

    goto _MsgLoop

End Sub